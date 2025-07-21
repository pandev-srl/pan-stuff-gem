# ValidationResponseSerializer

Il `ValidationResponseSerializer` è un serializzatore specializzato per creare risposte di validazione standardizzate, tipicamente utilizzato per confermare operazioni o fornire feedback strutturato.

## Panoramica

Il ValidationResponseSerializer fornisce:

- Serializzazione di oggetti con attributi per risposte di validazione
- Trasformazione automatica delle chiavi degli attributi
- Supporto per messaggi opzionali
- Struttura consistente per risposte di conferma
- Integrazione con ValidationResponse per risposte standardizzate

## Utilizzo Base

```ruby
# Con un oggetto ActiveRecord
user = User.create!(name: "John Doe", email: "john@example.com")
serializer = PanStuff::Serializer::ValidationResponseSerializer.new(user, "Utente creato con successo")
serializer.to_h
# => {
#   validationResponse: {
#     id: 1,
#     name: "John Doe",
#     email: "john@example.com",
#     createdAt: "2023-01-01T10:00:00Z",
#     updatedAt: "2023-01-01T10:00:00Z"
#   },
#   message: "Utente creato con successo"
# }
```

## ValidationResponse Class

PanStuff include una classe `ValidationResponse` per creare risposte standardizzate:

```ruby
# Creazione di una ValidationResponse
response = PanStuff::Serializer::ValidationResponse.new(
  id: "operation_123",
  status: 200,
  message: "Operazione completata con successo"
)

serializer = ValidationResponseSerializer.new(response)
serializer.to_h
# => {
#   validationResponse: {
#     id: "operation_123",
#     status: 200,
#     message: "Operazione completata con successo"
#   }
# }
```

## Struttura della Risposta

### Con Messaggio

```json
{
  "validationResponse": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "status": "active"
  },
  "message": "Operazione completata con successo"
}
```

### Senza Messaggio

```json
{
  "validationResponse": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "status": "active"
  }
}
```

## Esempi Pratici

### Conferma di Creazione

```ruby
class UsersController < ApplicationController
  def create
    @user = User.new(user_params)

    if @user.save
      serializer = ValidationResponseSerializer.new(@user, "Utente creato con successo")
      render json: serializer, status: :created
    else
      render json: ResourceErrorsSerializer.new(@user.errors), status: :unprocessable_entity
    end
  end
end
```

### Conferma di Aggiornamento

```ruby
class UsersController < ApplicationController
  def update
    @user = User.find(params[:id])

    if @user.update(user_params)
      serializer = ValidationResponseSerializer.new(@user, "Profilo aggiornato con successo")
      render json: serializer
    else
      render json: ResourceErrorsSerializer.new(@user.errors), status: :unprocessable_entity
    end
  end
end
```

### Operazioni Personalizzate

```ruby
class UsersController < ApplicationController
  def activate
    @user = User.find(params[:id])

    if @user.activate!
      response = ValidationResponse.new(
        id: @user.id.to_s,
        status: 200,
        message: "Account attivato con successo"
      )

      serializer = ValidationResponseSerializer.new(response)
      render json: serializer
    else
      render json: ResourceErrorsSerializer.new(@user.errors), status: :unprocessable_entity
    end
  end

  def deactivate
    @user = User.find(params[:id])

    if @user.deactivate!
      response = ValidationResponse.new(
        id: @user.id.to_s,
        status: 200,
        message: "Account disattivato"
      )

      serializer = ValidationResponseSerializer.new(response)
      render json: serializer
    else
      render json: ResourceErrorsSerializer.new(@user.errors), status: :unprocessable_entity
    end
  end
end
```

## Utilizzo con Form Objects

```ruby
class UserRegistrationForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attribute :name, :string
  attribute :email, :string
  attribute :password, :string

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 8 }

  def save
    return false unless valid?

    user = User.create!(attributes.except('password'))
    @id = user.id
    true
  end

  def id
    @id
  end
end

# Nel controller
def register
  form = UserRegistrationForm.new(registration_params)

  if form.save
    serializer = ValidationResponseSerializer.new(form, "Registrazione completata con successo")
    render json: serializer, status: :created
  else
    render json: ResourceErrorsSerializer.new(form.errors), status: :unprocessable_entity
  end
end
```

## Esempi Avanzati

### Operazioni Batch

```ruby
class BatchOperationService
  def process_users(user_ids, action)
    results = []
    errors = []

    user_ids.each do |id|
      user = User.find_by(id: id)

      if user && user.send("#{action}!")
        results << {
          id: user.id,
          name: user.name,
          status: user.status,
          action: action
        }
      else
        errors << { id: id, error: "Impossibile eseguire #{action}" }
      end
    end

    {
      successful: results,
      failed: errors,
      total_processed: user_ids.count
    }
  end
end

# Nel controller
def batch_activate
  service = BatchOperationService.new
  result = service.process_users(params[:user_ids], 'activate')

  response = ValidationResponse.new(
    id: SecureRandom.uuid,
    status: result[:failed].empty? ? 200 : 207, # 207 = Multi-Status
    message: "Processati #{result[:total_processed]} utenti"
  )

  # Aggiungi dettagli personalizzati
  response.define_singleton_method(:successful) { result[:successful] }
  response.define_singleton_method(:failed) { result[:failed] }

  serializer = ValidationResponseSerializer.new(response)
  render json: serializer
end
```

### Integrazione con Job Asincroni

```ruby
class AsyncOperationController < ApplicationController
  def start_import
    job = ImportUsersJob.perform_later(params[:file_path])

    response = ValidationResponse.new(
      id: job.job_id,
      status: 202, # Accepted
      message: "Importazione avviata"
    )

    # Aggiungi informazioni sul job
    response.define_singleton_method(:job_id) { job.job_id }
    response.define_singleton_method(:estimated_duration) { "5-10 minuti" }
    response.define_singleton_method(:status_url) { job_status_url(job.job_id) }

    serializer = ValidationResponseSerializer.new(response)
    render json: serializer, status: :accepted
  end

  def job_status
    job = ImportUsersJob.find(params[:job_id])

    response = ValidationResponse.new(
      id: job.job_id,
      status: job.completed? ? 200 : 102, # 102 = Processing
      message: job.status_message
    )

    # Aggiungi progresso
    response.define_singleton_method(:progress) { job.progress_percentage }
    response.define_singleton_method(:completed) { job.completed? }

    serializer = ValidationResponseSerializer.new(response)
    render json: serializer
  end
end
```

### Validazione Multi-Step

```ruby
class MultiStepFormController < ApplicationController
  def validate_step
    step_number = params[:step].to_i
    form_data = params[:form_data]

    validator = MultiStepValidator.new(step_number, form_data)

    if validator.valid?
      response = ValidationResponse.new(
        id: session[:form_session_id] ||= SecureRandom.uuid,
        status: 200,
        message: "Step #{step_number} validato con successo"
      )

      # Aggiungi informazioni sul progresso
      response.define_singleton_method(:current_step) { step_number }
      response.define_singleton_method(:total_steps) { validator.total_steps }
      response.define_singleton_method(:next_step_url) { next_step_url(step_number + 1) }
      response.define_singleton_method(:can_proceed) { true }

      serializer = ValidationResponseSerializer.new(response)
      render json: serializer
    else
      render json: ResourceErrorsSerializer.new(validator.errors), status: :unprocessable_entity
    end
  end
end
```

## Personalizzazione

### Estensione del Serializzatore

```ruby
class CustomValidationResponseSerializer < ValidationResponseSerializer
  def initialize(resource, message = nil, metadata: nil)
    super(resource, message)
    @metadata = metadata
  end

  protected

  def serializable_hash!
    result = super

    if @metadata
      result[run_key_transform!(:metadata)] = @metadata.deep_transform_keys do |key|
        run_key_transform!(key)
      end
    end

    # Aggiungi timestamp
    result[run_key_transform!(:timestamp)] = Time.current.iso8601

    result
  end
end

# Utilizzo
serializer = CustomValidationResponseSerializer.new(
  user,
  "Operazione completata",
  metadata: {
    operation_id: "op_123",
    duration_ms: 150,
    affected_records: 1
  }
)
```

### ValidationResponse Personalizzata

```ruby
class CustomValidationResponse < ValidationResponse
  attribute :operation_type, type: :string
  attribute :affected_records, type: :integer
  attribute :duration_ms, type: :integer
  attribute :metadata, type: :hash

  def success?
    status >= 200 && status < 300
  end

  def error?
    !success?
  end
end

# Utilizzo
response = CustomValidationResponse.new(
  id: "op_123",
  status: 200,
  message: "Operazione completata",
  operation_type: "user_creation",
  affected_records: 1,
  duration_ms: 150,
  metadata: { source: "api", version: "v1" }
)

serializer = ValidationResponseSerializer.new(response)
```

## Best Practices

1. **Messaggi Chiari**: Fornisci sempre messaggi informativi e user-friendly
2. **Codici di Stato Appropriati**: Usa codici HTTP corretti nel campo status
3. **ID Univoci**: Includi sempre un ID per tracciare le operazioni
4. **Consistenza**: Mantieni una struttura consistente per tutte le risposte
5. **Informazioni Utili**: Includi solo le informazioni necessarie per il client

## Codici di Stato Comuni

| Codice | Significato  | Uso Tipico                            |
| ------ | ------------ | ------------------------------------- |
| 200    | OK           | Operazione completata con successo    |
| 201    | Created      | Risorsa creata con successo           |
| 202    | Accepted     | Operazione accettata (asincrona)      |
| 204    | No Content   | Operazione completata senza contenuto |
| 207    | Multi-Status | Operazioni batch con risultati misti  |

## Integrazione con Frontend

```javascript
// Gestione delle risposte di validazione
async function handleValidationResponse(response) {
  const data = await response.json();

  if (data.validationResponse) {
    const validation = data.validationResponse;
    const message = data.message;

    // Mostra messaggio di successo
    if (message) {
      showSuccessMessage(message);
    }

    // Gestisci diversi tipi di status
    switch (validation.status) {
      case 200:
        handleSuccess(validation);
        break;
      case 202:
        handleAsyncOperation(validation);
        break;
      case 207:
        handleBatchResults(validation);
        break;
    }
  }
}

function handleAsyncOperation(validation) {
  if (validation.statusUrl) {
    // Polling per controllare lo stato
    pollJobStatus(validation.statusUrl);
  }
}
```

## Troubleshooting

### Attributi Mancanti

- Verifica che l'oggetto abbia il metodo `attributes`
- Controlla che gli attributi siano accessibili

### Trasformazione Chiavi

- Le chiavi vengono trasformate automaticamente (camelCase di default)
- Verifica la configurazione di `transform_method` se necessario

### Messaggi Non Visualizzati

- Assicurati di passare il messaggio come secondo parametro
- Controlla che il messaggio non sia nil o vuoto

### Performance

- Per oggetti con molti attributi, considera di limitare quelli serializzati
- Usa select specifici nelle query per ridurre i dati trasferiti
