# ObjectSerializer

L'`ObjectSerializer` è il serializzatore principale di PanStuff, progettato per convertire oggetti Ruby in rappresentazioni JSON strutturate per API.

## Panoramica

L'ObjectSerializer fornisce:

- Serializzazione di oggetti singoli e collezioni
- Trasformazione automatica delle chiavi (camelCase, underscore)
- Supporto per attributi personalizzati e metodi
- Gestione di metadati e messaggi
- Context per informazioni aggiuntive
- Serializzatori annidati

## Utilizzo Base

```ruby
class UserSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :email
  attribute :created_at
end

# Utilizzo
user = User.find(1)
serializer = UserSerializer.new(user)
serializer.to_h
# => { data: { id: 1, name: "John", email: "john@example.com", createdAt: "2023-01-01T00:00:00Z" } }
```

## Definizione degli Attributi

### Attributi Semplici

```ruby
class UserSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :email
end
```

### Attributi con Metodi Personalizzati

```ruby
class UserSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :full_name, method: :get_full_name
  attribute :avatar_url, method: :avatar_url

  private

  def get_full_name(user)
    "#{user.first_name} #{user.last_name}"
  end

  def avatar_url(user)
    user.avatar.present? ? user.avatar.url : '/default-avatar.png'
  end
end
```

### Attributi Condizionali

```ruby
class UserSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :email
  attribute :admin_notes, serialize_if: ->(context) { context[:current_user]&.admin? }
  attribute :private_data, serialize_if: ->(context) { context[:show_private] }
end
```

### Serializzatori Annidati

```ruby
class UserSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :company, serializer: CompanySerializer
  attribute :posts, serializer: PostSerializer
end

class CompanySerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :industry
end
```

## Inizializzazione

```ruby
# Oggetto singolo
UserSerializer.new(user)

# Con metadati
UserSerializer.new(user, meta: { total_count: 100 })

# Con messaggio
UserSerializer.new(user, message: "Utente creato con successo")

# Con context
UserSerializer.new(user, context: { current_user: current_user })

# Senza root (per serializzatori annidati)
UserSerializer.new(user, root: false)

# Esempio completo
UserSerializer.new(
  user,
  meta: { page: 1, per_page: 10 },
  message: "Operazione completata",
  context: { current_user: current_user, permissions: [:read, :write] },
  root: true
)
```

## Trasformazione delle Chiavi

### Configurazione Globale

```ruby
class UserSerializer
  include PanStuff::Serializer::ObjectSerializer

  # Usa camelCase (default)
  transform_method :camel_lower

  # Oppure usa underscore
  transform_method :underscore

  attribute :first_name
  attribute :last_name
end
```

### Risultati con Diverse Trasformazioni

```ruby
# Con camel_lower (default)
{ firstName: "John", lastName: "Doe" }

# Con underscore
{ first_name: "John", last_name: "Doe" }
```

## Gestione delle Collezioni

```ruby
users = User.all
serializer = UserSerializer.new(users)
serializer.to_h
# => {
#   data: [
#     { id: 1, name: "John" },
#     { id: 2, name: "Jane" }
#   ]
# }
```

## Context e Informazioni Aggiuntive

```ruby
class UserSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :email
  attribute :can_edit, method: :user_can_edit
  attribute :role, serialize_if: ->(context) { context[:show_roles] }

  private

  def user_can_edit(user)
    context[:current_user]&.can_edit?(user)
  end
end

# Utilizzo con context
UserSerializer.new(
  user,
  context: {
    current_user: current_user,
    show_roles: true
  }
)
```

## Struttura della Risposta

### Con Root (default)

```ruby
{
  "data": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com"
  },
  "meta": {
    "totalCount": 100,
    "page": 1
  },
  "message": "Operazione completata"
}
```

### Senza Root

```ruby
{
  "id": 1,
  "name": "John Doe",
  "email": "john@example.com"
}
```

## Esempi Avanzati

### Serializzatore con Relazioni Multiple

```ruby
class UserSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :email
  attribute :company, serializer: CompanySerializer
  attribute :posts, serializer: PostSerializer
  attribute :recent_activity, method: :get_recent_activity

  private

  def get_recent_activity(user)
    user.activities.recent.limit(5).map do |activity|
      {
        type: activity.type,
        description: activity.description,
        created_at: activity.created_at
      }
    end
  end
end
```

### Serializzatore con Logica Condizionale Complessa

```ruby
class UserSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :email
  attribute :phone, serialize_if: ->(context) { can_view_phone?(context) }
  attribute :admin_data, serialize_if: ->(context) { context[:current_user]&.admin? }
  attribute :profile_completion, method: :calculate_profile_completion

  private

  def self.can_view_phone?(context)
    current_user = context[:current_user]
    return false unless current_user

    current_user.admin? || context[:show_private_data]
  end

  def calculate_profile_completion(user)
    total_fields = 10
    completed_fields = [
      user.name,
      user.email,
      user.phone,
      user.bio,
      user.avatar
    ].compact.count

    (completed_fields.to_f / total_fields * 100).round(2)
  end
end
```

## Metodi Disponibili

### Metodi Pubblici

- `to_h` / `to_hash` - Restituisce l'hash serializzato
- `as_json(opts = nil)` - Restituisce JSON string

### Metodi di Classe

- `attribute(name, options = {})` - Definisce un attributo
- `transform_method(method)` - Imposta la trasformazione delle chiavi
- `collection?(resource)` - Verifica se la risorsa è una collezione

### Opzioni per `attribute`

- `:method` - Metodo personalizzato per ottenere il valore
- `:serializer` - Serializzatore per attributi annidati
- `:serialize_if` - Condizione per includere l'attributo

## Best Practices

1. **Separazione delle Responsabilità**: Mantieni la logica di business nei model, usa i serializzatori solo per la presentazione
2. **Context Minimale**: Passa solo le informazioni necessarie nel context
3. **Attributi Condizionali**: Usa `serialize_if` per attributi sensibili o opzionali
4. **Metodi Privati**: Definisci metodi helper come privati
5. **Serializzatori Annidati**: Usa serializzatori separati per relazioni complesse
6. **Performance**: Considera l'uso di `includes` per evitare query N+1

## Troubleshooting

### Attributo Non Trovato

Se un attributo non appare nella serializzazione:

- Verifica che l'oggetto abbia il metodo/attributo
- Controlla le condizioni `serialize_if`
- Assicurati che il metodo personalizzato sia definito

### Errori di Trasformazione Chiavi

- Verifica che `transform_method` sia uno dei valori supportati: `:camel_lower`, `:underscore`

### Performance Issues

- Usa `includes` per precaricamento delle associazioni
- Evita query complesse nei metodi del serializzatore
- Considera la cache per calcoli costosi
