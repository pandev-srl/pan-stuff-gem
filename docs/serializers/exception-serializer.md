# ExceptionSerializer

L'`ExceptionSerializer` è un serializzatore specializzato per gestire e formattare eccezioni e errori in modo standardizzato nelle risposte API.

## Panoramica

L'ExceptionSerializer fornisce una struttura consistente per:

- Serializzazione di eccezioni
- Gestione di errori personalizzati
- Standardizzazione delle risposte di errore
- Inclusione di codici di stato HTTP

## Utilizzo Base

```ruby
# Eccezione semplice
begin
  # Codice che può generare un'eccezione
  raise StandardError, "Qualcosa è andato storto"
rescue => e
  serializer = PanStuff::Serializer::ExceptionSerializer.new(
    status: 500,
    error: e.message,
    exception: e.class.name
  )
  serializer.to_h
end
# => {
#   validationResponse: {
#     status: 500,
#     error: "Qualcosa è andato storto",
#     exception: "StandardError"
#   }
# }
```

## Parametri di Inizializzazione

```ruby
ExceptionSerializer.new(
  status: 404,                    # Codice di stato HTTP
  error: "Risorsa non trovata",   # Messaggio di errore
  exception: "ActiveRecord::RecordNotFound", # Nome dell'eccezione
  root: true                      # Include il wrapper root
)
```

## Struttura della Risposta

### Con Root (default)

```json
{
  "validationResponse": {
    "status": 404,
    "error": "Risorsa non trovata",
    "exception": "ActiveRecord::RecordNotFound"
  }
}
```

### Senza Root

```json
{
  "status": 404,
  "error": "Risorsa non trovata",
  "exception": "ActiveRecord::RecordNotFound"
}
```

## Esempi per Diversi Tipi di Errore

### Errore 404 - Risorsa Non Trovata

```ruby
begin
  user = User.find(999)
rescue ActiveRecord::RecordNotFound => e
  serializer = ExceptionSerializer.new(
    status: 404,
    error: "Utente non trovato",
    exception: e.class.name
  )
  render json: serializer, status: :not_found
end
```

### Errore 401 - Non Autorizzato

```ruby
serializer = ExceptionSerializer.new(
  status: 401,
  error: "Token di accesso non valido o scaduto",
  exception: "UnauthorizedError"
)
render json: serializer, status: :unauthorized
```

### Errore 403 - Accesso Negato

```ruby
serializer = ExceptionSerializer.new(
  status: 403,
  error: "Non hai i permessi per accedere a questa risorsa",
  exception: "ForbiddenError"
)
render json: serializer, status: :forbidden
```

### Errore 500 - Errore Interno del Server

```ruby
begin
  # Operazione che può fallire
  complex_operation
rescue => e
  Rails.logger.error "Errore interno: #{e.message}"
  Rails.logger.error e.backtrace.join("\n")

  serializer = ExceptionSerializer.new(
    status: 500,
    error: "Si è verificato un errore interno del server",
    exception: e.class.name
  )
  render json: serializer, status: :internal_server_error
end
```

## Utilizzo nei Controller

### Gestione Globale degli Errori

```ruby
class ApplicationController < ActionController::API
  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :handle_invalid_record

  private

  def handle_standard_error(exception)
    serializer = ExceptionSerializer.new(
      status: 500,
      error: "Si è verificato un errore interno",
      exception: exception.class.name
    )
    render json: serializer, status: :internal_server_error
  end

  def handle_not_found(exception)
    serializer = ExceptionSerializer.new(
      status: 404,
      error: "Risorsa non trovata",
      exception: exception.class.name
    )
    render json: serializer, status: :not_found
  end

  def handle_invalid_record(exception)
    serializer = ExceptionSerializer.new(
      status: 422,
      error: "Dati non validi",
      exception: exception.class.name
    )
    render json: serializer, status: :unprocessable_entity
  end
end
```

### Gestione Specifica nel Controller

```ruby
class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    render json: UserSerializer.new(@user)
  rescue ActiveRecord::RecordNotFound
    error_response = ExceptionSerializer.new(
      status: 404,
      error: "Utente con ID #{params[:id]} non trovato"
    )
    render json: error_response, status: :not_found
  end

  def create
    @user = User.create!(user_params)
    render json: UserSerializer.new(@user), status: :created
  rescue ActiveRecord::RecordInvalid => e
    error_response = ExceptionSerializer.new(
      status: 422,
      error: "Impossibile creare l'utente: #{e.message}",
      exception: e.class.name
    )
    render json: error_response, status: :unprocessable_entity
  end
end
```

## Integrazione con Middleware

```ruby
class ErrorHandlingMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(env)
  rescue => exception
    handle_exception(exception)
  end

  private

  def handle_exception(exception)
    status = status_code_for(exception)

    serializer = PanStuff::Serializer::ExceptionSerializer.new(
      status: status,
      error: user_friendly_message(exception),
      exception: exception.class.name
    )

    [
      status,
      { 'Content-Type' => 'application/json' },
      [serializer.to_h.to_json]
    ]
  end

  def status_code_for(exception)
    case exception
    when ActiveRecord::RecordNotFound
      404
    when ActiveRecord::RecordInvalid
      422
    when ArgumentError
      400
    else
      500
    end
  end

  def user_friendly_message(exception)
    case exception
    when ActiveRecord::RecordNotFound
      "Risorsa richiesta non trovata"
    when ActiveRecord::RecordInvalid
      "I dati forniti non sono validi"
    when ArgumentError
      "Parametri non validi nella richiesta"
    else
      "Si è verificato un errore interno del server"
    end
  end
end
```

## Esempi Avanzati

### Errori con Informazioni Aggiuntive

```ruby
class CustomExceptionSerializer < PanStuff::Serializer::ExceptionSerializer
  def initialize(status: nil, error: nil, exception: nil, details: nil, root: true)
    super(status: status, error: error, exception: exception, root: root)
    @details = details
  end

  protected

  def serializable_hash!
    result = super

    if @details && root
      result[run_key_transform!(:validation_response)][run_key_transform!(:details)] = @details
    elsif @details
      result[run_key_transform!(:details)] = @details
    end

    result
  end
end

# Utilizzo
serializer = CustomExceptionSerializer.new(
  status: 400,
  error: "Parametri di ricerca non validi",
  exception: "SearchError",
  details: {
    invalid_fields: ["date_from", "date_to"],
    suggestions: ["Usa formato YYYY-MM-DD per le date"]
  }
)
```

### Logging Automatico degli Errori

```ruby
class LoggingExceptionSerializer < PanStuff::Serializer::ExceptionSerializer
  def initialize(status: nil, error: nil, exception: nil, root: true, request_id: nil)
    super(status: status, error: error, exception: exception, root: root)
    @request_id = request_id
    log_error
  end

  private

  def log_error
    Rails.logger.error({
      timestamp: Time.current.iso8601,
      request_id: @request_id,
      status: status,
      error: error,
      exception: exception
    }.to_json)
  end
end
```

## Best Practices

1. **Consistenza**: Usa sempre ExceptionSerializer per tutti gli errori API
2. **Sicurezza**: Non esporre dettagli sensibili negli errori di produzione
3. **Logging**: Registra sempre gli errori per debugging
4. **Codici di Stato**: Usa codici HTTP appropriati
5. **Messaggi User-Friendly**: Fornisci messaggi comprensibili agli utenti

## Codici di Stato Comuni

| Codice | Significato           | Uso Tipico               |
| ------ | --------------------- | ------------------------ |
| 400    | Bad Request           | Parametri non validi     |
| 401    | Unauthorized          | Autenticazione richiesta |
| 403    | Forbidden             | Accesso negato           |
| 404    | Not Found             | Risorsa non trovata      |
| 422    | Unprocessable Entity  | Errori di validazione    |
| 500    | Internal Server Error | Errori del server        |

## Integrazione con Sistemi di Monitoraggio

```ruby
class MonitoredExceptionSerializer < PanStuff::Serializer::ExceptionSerializer
  def initialize(status: nil, error: nil, exception: nil, root: true)
    super(status: status, error: error, exception: exception, root: root)
    report_to_monitoring_service
  end

  private

  def report_to_monitoring_service
    return unless Rails.env.production?
    return if status < 500 # Solo errori del server

    # Integrazione con Sentry, Bugsnag, etc.
    ErrorReportingService.notify(
      exception: exception,
      error: error,
      status: status,
      context: {
        timestamp: Time.current,
        environment: Rails.env
      }
    )
  end
end
```

## Troubleshooting

### Errori Non Serializzati Correttamente

- Verifica che tutti i parametri siano stringhe o numeri
- Controlla che il root sia impostato correttamente

### Informazioni Mancanti

- Assicurati di passare tutti i parametri necessari
- Verifica che i messaggi di errore siano informativi

### Performance Issues

- Evita operazioni costose nel serializzatore
- Considera la cache per messaggi di errore comuni

### Sicurezza

- Non esporre stack trace in produzione
- Filtra informazioni sensibili dai messaggi di errore
