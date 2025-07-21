# ResourceErrorsSerializer

Il `ResourceErrorsSerializer` è un serializzatore specializzato per gestire e formattare gli errori di validazione di ActiveRecord in modo standardizzato per le API.

## Panoramica

Il ResourceErrorsSerializer fornisce:

- Serializzazione degli errori di validazione ActiveRecord
- Messaggi di errore completi e leggibili
- Dettagli strutturati degli errori per campo
- Trasformazione automatica delle chiavi
- Formato consistente per le risposte di errore

## Utilizzo Base

```ruby
# Model con errori di validazione
user = User.new(email: "invalid-email")
user.valid? # => false

# Serializza gli errori
serializer = PanStuff::Serializer::ResourceErrorsSerializer.new(user.errors)
serializer.to_h
# => {
#   errors: [
#     "Email non è valido",
#     "Nome non può essere vuoto"
#   ],
#   details: {
#     email: [
#       { error: "invalid" }
#     ],
#     name: [
#       { error: "blank" }
#     ]
#   }
# }
```

## Struttura della Risposta

La risposta contiene sempre due sezioni principali:

### `errors` - Messaggi Completi

Array di messaggi di errore leggibili dall'utente.

### `details` - Dettagli Strutturati

Hash con dettagli specifici per ogni campo, inclusi codici di errore e parametri aggiuntivi.

```json
{
  "errors": [
    "Email non è valido",
    "Nome non può essere vuoto",
    "Password è troppo corta (minimo 8 caratteri)"
  ],
  "details": {
    "email": [{ "error": "invalid" }],
    "name": [{ "error": "blank" }],
    "password": [
      {
        "error": "tooShort",
        "count": 8
      }
    ]
  }
}
```

## Esempi con Diversi Tipi di Validazione

### Validazioni Base

```ruby
class User < ApplicationRecord
  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :age, numericality: { greater_than: 0, less_than: 120 }
end

user = User.new(name: "", email: "invalid", age: -5)
user.valid? # => false

serializer = ResourceErrorsSerializer.new(user.errors)
serializer.to_h
# => {
#   errors: [
#     "Nome non può essere vuoto",
#     "Email non è valido",
#     "Età deve essere maggiore di 0"
#   ],
#   details: {
#     name: [{ error: "blank" }],
#     email: [{ error: "invalid" }],
#     age: [{ error: "greaterThan", count: 0 }]
#   }
# }
```

### Validazioni con Parametri

```ruby
class Product < ApplicationRecord
  validates :name, presence: true, length: { minimum: 3, maximum: 100 }
  validates :price, numericality: { greater_than: 0 }
  validates :category, inclusion: { in: %w[electronics clothing books] }
end

product = Product.new(name: "AB", price: -10, category: "invalid")
product.valid? # => false

serializer = ResourceErrorsSerializer.new(product.errors)
serializer.to_h
# => {
#   errors: [
#     "Nome è troppo corto (minimo 3 caratteri)",
#     "Prezzo deve essere maggiore di 0",
#     "Categoria non è incluso nella lista"
#   ],
#   details: {
#     name: [{ error: "tooShort", count: 3 }],
#     price: [{ error: "greaterThan", count: 0 }],
#     category: [{ error: "inclusion", value: "invalid" }]
#   }
# }
```

### Validazioni Personalizzate

```ruby
class User < ApplicationRecord
  validate :password_complexity

  private

  def password_complexity
    return unless password.present?

    unless password.match?(/[A-Z]/)
      errors.add(:password, :no_uppercase, message: "deve contenere almeno una lettera maiuscola")
    end

    unless password.match?(/[0-9]/)
      errors.add(:password, :no_number, message: "deve contenere almeno un numero")
    end
  end
end

user = User.new(password: "simple")
user.valid? # => false

serializer = ResourceErrorsSerializer.new(user.errors)
serializer.to_h
# => {
#   errors: [
#     "Password deve contenere almeno una lettera maiuscola",
#     "Password deve contenere almeno un numero"
#   ],
#   details: {
#     password: [
#       { error: "noUppercase" },
#       { error: "noNumber" }
#     ]
#   }
# }
```

## Utilizzo nei Controller

### Con ResourcesController

Il ResourcesController di PanStuff usa automaticamente ResourceErrorsSerializer:

```ruby
class UsersController < ApplicationController
  include PanStuff::ResourcesController

  # Gli errori vengono automaticamente serializzati quando
  # @resource.errors.any? è true
end
```

### Utilizzo Manuale

```ruby
class UsersController < ApplicationController
  def create
    @user = User.new(user_params)

    if @user.save
      render json: UserSerializer.new(@user), status: :created
    else
      render json: ResourceErrorsSerializer.new(@user.errors), status: :unprocessable_entity
    end
  end

  def update
    @user = User.find(params[:id])

    if @user.update(user_params)
      render json: UserSerializer.new(@user)
    else
      render json: ResourceErrorsSerializer.new(@user.errors), status: :unprocessable_entity
    end
  end
end
```

## Esempi Avanzati

### Errori su Associazioni

```ruby
class Order < ApplicationRecord
  has_many :order_items
  validates_associated :order_items

  accepts_nested_attributes_for :order_items
end

class OrderItem < ApplicationRecord
  belongs_to :order
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than: 0 }
end

# Creazione con errori nelle associazioni
order_params = {
  customer_name: "John Doe",
  order_items_attributes: [
    { quantity: 0, price: -10 },
    { quantity: "", price: "" }
  ]
}

order = Order.new(order_params)
order.valid? # => false

serializer = ResourceErrorsSerializer.new(order.errors)
# Gli errori includeranno anche quelli delle associazioni
```

### Gestione di Errori Multipli per Campo

```ruby
class User < ApplicationRecord
  validates :password, presence: true, length: { minimum: 8 }, format: { with: /[A-Z]/ }
end

user = User.new(password: "ab")
user.valid? # => false

serializer = ResourceErrorsSerializer.new(user.errors)
serializer.to_h
# => {
#   errors: [
#     "Password è troppo corta (minimo 8 caratteri)",
#     "Password non è valida"
#   ],
#   details: {
#     password: [
#       { error: "tooShort", count: 8 },
#       { error: "invalid" }
#     ]
#   }
# }
```

### Integrazione con Form Objects

```ruby
class UserRegistrationForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attribute :name, :string
  attribute :email, :string
  attribute :password, :string
  attribute :password_confirmation, :string

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 8 }
  validates :password_confirmation, presence: true
  validate :passwords_match

  private

  def passwords_match
    return unless password.present? && password_confirmation.present?

    errors.add(:password_confirmation, :confirmation) unless password == password_confirmation
  end
end

# Nel controller
def register
  form = UserRegistrationForm.new(registration_params)

  if form.valid?
    # Crea l'utente
    user = User.create!(form.attributes.except('password_confirmation'))
    render json: UserSerializer.new(user), status: :created
  else
    render json: ResourceErrorsSerializer.new(form.errors), status: :unprocessable_entity
  end
end
```

## Personalizzazione

### Estensione del Serializzatore

```ruby
class CustomResourceErrorsSerializer < PanStuff::Serializer::ResourceErrorsSerializer
  def initialize(errors, context: nil)
    super(errors)
    @context = context || {}
  end

  private

  def serializable_hash!
    result = super

    # Aggiungi informazioni di contesto
    result[run_key_transform!(:context)] = @context if @context.any?

    # Aggiungi timestamp
    result[run_key_transform!(:timestamp)] = Time.current.iso8601

    result
  end
end
```

### Messaggi di Errore Localizzati

```ruby
# config/locales/it.yml
it:
  activerecord:
    errors:
      models:
        user:
          attributes:
            email:
              invalid: "deve essere un indirizzo email valido"
              blank: "è obbligatorio"
            password:
              too_short: "deve contenere almeno %{count} caratteri"
              blank: "è obbligatorio"

# I messaggi localizzati verranno automaticamente utilizzati
user = User.new(email: "invalid")
user.valid?
ResourceErrorsSerializer.new(user.errors).to_h
# => { errors: ["Email deve essere un indirizzo email valido"], ... }
```

## Integrazione con Frontend

### Gestione Errori in JavaScript

```javascript
// Esempio di gestione errori nel frontend
async function createUser(userData) {
  try {
    const response = await fetch("/api/users", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ user: userData }),
    });

    if (!response.ok) {
      const errorData = await response.json();

      if (response.status === 422) {
        // Errori di validazione
        displayValidationErrors(errorData.errors, errorData.details);
      } else {
        // Altri errori
        displayGenericError("Errore durante la creazione dell'utente");
      }
      return;
    }

    const user = await response.json();
    displaySuccess("Utente creato con successo");
  } catch (error) {
    displayGenericError("Errore di connessione");
  }
}

function displayValidationErrors(errors, details) {
  // Mostra messaggi generali
  errors.forEach((error) => showErrorMessage(error));

  // Evidenzia campi specifici
  Object.keys(details).forEach((field) => {
    const fieldElement = document.querySelector(`[name="${field}"]`);
    if (fieldElement) {
      fieldElement.classList.add("error");

      // Mostra dettagli specifici per il campo
      const fieldErrors = details[field].map((detail) => detail.error);
      showFieldError(fieldElement, fieldErrors);
    }
  });
}
```

## Best Practices

1. **Usa Sempre per Errori di Validazione**: Standardizza la gestione degli errori
2. **Messaggi Localizzati**: Configura i messaggi in base alla lingua dell'utente
3. **Codici di Errore Consistenti**: Usa codici di errore standardizzati
4. **Informazioni Sufficienti**: Fornisci abbastanza dettagli per il debugging
5. **Sicurezza**: Non esporre informazioni sensibili negli errori

## Codici di Errore Comuni

| Codice         | Significato              | Esempio                     |
| -------------- | ------------------------ | --------------------------- |
| `blank`        | Campo vuoto              | Nome obbligatorio           |
| `invalid`      | Formato non valido       | Email non valida            |
| `too_short`    | Troppo corto             | Password minimo 8 caratteri |
| `too_long`     | Troppo lungo             | Nome massimo 100 caratteri  |
| `greater_than` | Deve essere maggiore     | Età > 0                     |
| `less_than`    | Deve essere minore       | Età < 120                   |
| `inclusion`    | Non nella lista          | Categoria non valida        |
| `exclusion`    | Nella lista proibita     | Username riservato          |
| `confirmation` | Conferma non corrisponde | Password non confermata     |
| `accepted`     | Deve essere accettato    | Termini di servizio         |

## Troubleshooting

### Errori Non Visualizzati

- Verifica che l'oggetto errors sia di ActiveModel::Errors
- Controlla che le validazioni siano configurate correttamente

### Messaggi Non Localizzati

- Verifica la configurazione dei file di localizzazione
- Controlla che la locale sia impostata correttamente

### Dettagli Mancanti

- Assicurati che le validazioni includano i parametri necessari
- Verifica che i codici di errore siano corretti

### Performance Issues

- Per modelli con molte validazioni, considera la validazione condizionale
- Usa validazioni database quando possibile per performance migliori
