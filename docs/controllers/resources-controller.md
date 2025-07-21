# ResourcesController

Il `ResourcesController` è un modulo che fornisce un'implementazione standardizzata per le operazioni CRUD (Create, Read, Update, Delete) su risorse API.

## Panoramica

Questo modulo implementa i metodi standard di un controller REST:

- `index` - Lista delle risorse
- `show` - Visualizza una singola risorsa
- `create` - Crea una nuova risorsa
- `update` - Aggiorna una risorsa esistente
- `destroy` - Elimina una risorsa

## Utilizzo Base

```ruby
class UsersController < ApplicationController
  include PanStuff::ResourcesController

  private

  # Metodi obbligatori da implementare
  def resource_service_class
    UserService
  end

  def resource_serializer
    UserSerializer
  end

  def resource_location
    user_path(@resource)
  end

  def resource_params_root_key
    :user
  end
end
```

## Metodi Obbligatori

Questi metodi devono essere implementati nella classe che include il modulo:

### `resource_service_class`

Restituisce la classe del service che gestisce la logica di business.

```ruby
def resource_service_class
  UserService
end
```

### `resource_serializer`

Restituisce la classe del serializzatore per la risorsa.

```ruby
def resource_serializer
  UserSerializer
end
```

### `resource_location`

Restituisce l'URL della risorsa per l'header `Location` nelle risposte.

```ruby
def resource_location
  user_path(@resource)
end
```

### `resource_params_root_key`

Restituisce la chiave root per i parametri della risorsa.

```ruby
def resource_params_root_key
  :user
end
```

## Metodi Opzionali

### Messaggi Personalizzati

```ruby
def create_message
  "Utente creato con successo"
end

def update_message
  "Utente aggiornato con successo"
end

def destroy_message
  "Utente eliminato con successo"
end
```

### Serializzatori Specifici per Azione

```ruby
def index_resource_serializer
  UserListSerializer
end

def show_resource_serializer
  UserDetailSerializer
end

def create_resource_serializer
  UserCreateSerializer
end

def update_resource_serializer
  UserUpdateSerializer
end

def destroy_resource_serializer
  UserDestroySerializer
end
```

### Parametri Personalizzati

```ruby
def resource_key_param
  params[:user_id] # invece del default params[:id]
end

def ancestry_key_params
  { company_id: params[:company_id] }
end

def resource_create_params
  resource_params.merge(created_by: current_user.id)
end

def resource_update_params
  resource_params.merge(updated_by: current_user.id)
end
```

## Gestione del Context

Il controller fornisce un sistema di context per passare informazioni aggiuntive ai serializzatori:

```ruby
def show
  add_meta(:current_user_id, current_user.id)
  self.context = { user: current_user, permissions: user_permissions }

  super
end
```

## Gestione dei Metadati

```ruby
def index
  add_meta(:total_count, User.count)
  add_meta(:filters_applied, applied_filters)

  super
end
```

## Esempio Completo

```ruby
class UsersController < ApplicationController
  include PanStuff::ResourcesController

  before_action :authenticate_user!
  before_action :set_context

  private

  def resource_service_class
    UserService
  end

  def resource_serializer
    UserSerializer
  end

  def resource_location
    api_v1_user_path(@resource)
  end

  def resource_params_root_key
    :user
  end

  def create_message
    "Utente creato con successo"
  end

  def update_message
    "Utente aggiornato con successo"
  end

  def destroy_message
    "Utente eliminato con successo"
  end

  def set_context
    self.context = {
      current_user: current_user,
      permissions: current_user.permissions
    }
  end

  def ancestry_key_params
    { company_id: params[:company_id] }
  end

  def resource_create_params
    resource_params.merge(
      created_by: current_user.id,
      company_id: current_user.company_id
    )
  end

  def resource_update_params
    resource_params.merge(updated_by: current_user.id)
  end
end
```

## Service Class

Il service deve implementare i seguenti metodi:

```ruby
class UserService
  def all(ancestry_params = {})
    # Restituisce la collezione di risorse
    User.where(ancestry_params)
  end

  def find(ancestry_params, id)
    # Trova una singola risorsa
    User.where(ancestry_params).find(id)
  end

  def create(ancestry_params, params)
    # Crea una nuova risorsa
    User.create(ancestry_params.merge(params))
  end

  def update(ancestry_params, id, params)
    # Aggiorna una risorsa esistente
    user = User.where(ancestry_params).find(id)
    user.update(params)
    user
  end

  def destroy(ancestry_params, id)
    # Elimina una risorsa
    user = User.where(ancestry_params).find(id)
    user.destroy
    user
  end
end
```

## Risposte API

### Successo (200/201)

```json
{
  "data": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com"
  },
  "meta": {
    "current_user_id": 123
  },
  "message": "Utente creato con successo"
}
```

### Errore di Validazione (422)

```json
{
  "errors": {
    "name": ["non può essere vuoto"],
    "email": ["non è valido"]
  }
}
```

## Best Practices

1. **Separazione delle Responsabilità**: Usa sempre un service class per la logica di business
2. **Serializzatori Specifici**: Considera l'uso di serializzatori diversi per azioni diverse
3. **Context Appropriato**: Passa solo le informazioni necessarie nel context
4. **Gestione Errori**: Lascia che il controller gestisca automaticamente gli errori di validazione
5. **Parametri Sicuri**: Implementa sempre `resource_params` in modo sicuro

## Troubleshooting

### Errore: MethodNotOverriddenError

Questo errore indica che non hai implementato uno dei metodi obbligatori. Assicurati di aver definito:

- `resource_service_class`
- `resource_serializer`
- `resource_location`
- `resource_params_root_key`

### Parametri Non Trovati

Se ricevi `ActionController::ParameterMissing`, verifica che:

- Il client stia inviando i parametri con la chiave corretta
- `resource_params_root_key` restituisca la chiave corretta
