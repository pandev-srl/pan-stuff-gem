# Guida Introduttiva

Questa guida ti aiuterà a iniziare rapidamente con PanStuff, fornendo esempi pratici e pattern comuni per lo sviluppo di API Rails.

## Installazione

Aggiungi PanStuff al tuo Gemfile:

```ruby
gem 'pan_stuff'
```

Esegui bundle install:

```bash
bundle install
```

## Setup Base

### 1. Controller Base

Crea un controller base per la tua API:

```ruby
# app/controllers/api/base_controller.rb
class Api::BaseController < ActionController::API
  include PanStuff::ParamsHelpers

  # Gestione globale degli errori
  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :handle_invalid_record

  private

  def handle_standard_error(exception)
    Rails.logger.error "Errore interno: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    serializer = PanStuff::Serializer::ExceptionSerializer.new(
      status: 500,
      error: "Si è verificato un errore interno del server",
      exception: exception.class.name
    )
    render json: serializer, status: :internal_server_error
  end

  def handle_not_found(exception)
    serializer = PanStuff::Serializer::ExceptionSerializer.new(
      status: 404,
      error: "Risorsa non trovata",
      exception: exception.class.name
    )
    render json: serializer, status: :not_found
  end

  def handle_invalid_record(exception)
    render json: PanStuff::Serializer::ResourceErrorsSerializer.new(exception.record.errors),
           status: :unprocessable_entity
  end
end
```

### 2. Modello con Paginazione

Aggiungi la paginazione ai tuoi modelli:

```ruby
# app/models/user.rb
class User < ApplicationRecord
  include PanStuff::ActiveRecordPagination

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }
  scope :search, ->(term) { where('name ILIKE ? OR email ILIKE ?', "%#{term}%", "%#{term}%") }
end
```

### 3. Serializzatore Base

Crea un serializzatore per il tuo modello:

```ruby
# app/serializers/user_serializer.rb
class UserSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :email
  attribute :active
  attribute :created_at
  attribute :updated_at
end
```

## Primo Controller CRUD

### Approccio Manuale

```ruby
# app/controllers/api/users_controller.rb
class Api::UsersController < Api::BaseController
  def index
    # Filtri dalla query string
    filters = query_params

    users = User.includes(:company)
    users = users.active if filters[:active] == 'true'
    users = users.search(filters[:search]) if filters[:search].present?

    # Paginazione
    paginated_users, metadata = users.paginate(
      current_page: filters[:page]&.to_i || 1,
      items_per_page: filters[:per_page]&.to_i || 20
    )

    render json: {
      data: UserSerializer.new(paginated_users).to_h[:data],
      pagination: metadata
    }
  end

  def show
    user = User.find(params[:id])
    render json: UserSerializer.new(user)
  end

  def create
    user_params = request_params[:user]
    user = User.new(user_params)

    if user.save
      render json: UserSerializer.new(user), status: :created
    else
      render json: PanStuff::Serializer::ResourceErrorsSerializer.new(user.errors),
             status: :unprocessable_entity
    end
  end

  def update
    user = User.find(params[:id])
    user_params = request_params[:user]

    if user.update(user_params)
      render json: UserSerializer.new(user)
    else
      render json: PanStuff::Serializer::ResourceErrorsSerializer.new(user.errors),
             status: :unprocessable_entity
    end
  end

  def destroy
    user = User.find(params[:id])

    if user.destroy
      render json: PanStuff::Serializer::ValidationResponseSerializer.new(
        user, "Utente eliminato con successo"
      )
    else
      render json: PanStuff::Serializer::ResourceErrorsSerializer.new(user.errors),
             status: :unprocessable_entity
    end
  end
end
```

### Approccio con ResourcesController

```ruby
# app/controllers/api/users_controller.rb
class Api::UsersController < Api::BaseController
  include PanStuff::ResourcesController

  private

  def resource_service_class
    UserService
  end

  def resource_serializer
    UserSerializer
  end

  def resource_location
    api_user_path(@resource)
  end

  def resource_params_root_key
    :user
  end

  def resource_collection_resolver
    users = User.includes(:company)

    # Applica filtri
    filters = query_params
    users = users.active if filters[:active] == 'true'
    users = users.search(filters[:search]) if filters[:search].present?

    # Paginazione
    paginated_users, metadata = users.paginate(
      current_page: filters[:page]&.to_i || 1,
      items_per_page: filters[:per_page]&.to_i || 20
    )

    add_meta(:pagination, metadata)
    paginated_users
  end
end

# app/services/user_service.rb
class UserService
  def all(ancestry_params = {})
    User.where(ancestry_params)
  end

  def find(ancestry_params, id)
    User.where(ancestry_params).find(id)
  end

  def create(ancestry_params, params)
    User.create(ancestry_params.merge(params))
  end

  def update(ancestry_params, id, params)
    user = User.where(ancestry_params).find(id)
    user.update(params)
    user
  end

  def destroy(ancestry_params, id)
    user = User.where(ancestry_params).find(id)
    user.destroy
    user
  end
end
```

## Esempi di Serializzazione

### Serializzatore con Relazioni

```ruby
class UserSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :email
  attribute :company, serializer: CompanySerializer
  attribute :full_name, method: :get_full_name
  attribute :avatar_url, method: :avatar_url

  private

  def get_full_name(user)
    "#{user.first_name} #{user.last_name}".strip
  end

  def avatar_url(user)
    user.avatar.present? ? user.avatar.url : '/default-avatar.png'
  end
end

class CompanySerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :industry
end
```

### Serializzazione con Money

```ruby
class ProductSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :description
  attribute :price, serializer: PanStuff::Serializer::MoneySerializer
  attribute :sale_price, serializer: PanStuff::Serializer::MoneySerializer
end

# Risultato:
# {
#   "data": {
#     "id": 1,
#     "name": "Laptop",
#     "price": {
#       "cents": 99999,
#       "amount": 999.99,
#       "currency": "EUR",
#       "formattedText": "€ 999.99",
#       "symbol": "€"
#     }
#   }
# }
```

### Hash Serialization

```ruby
# Per dati semplici o aggregazioni
def dashboard
  stats = {
    total_users: User.count,
    active_users: User.active.count,
    new_users_today: User.where(created_at: Date.current.all_day).count
  }

  render json: PanStuff::Serializer::HashSerializer.new(stats)
end

# Con SmartHashSerializer per oggetti Money
def financial_summary
  data = {
    total_revenue: Money.new(150000, "EUR"),
    monthly_revenue: Money.new(25000, "EUR"),
    average_order: Money.new(7500, "EUR")
  }

  render json: PanStuff::Serializer::SmartHashSerializer.new(data)
end
```

## Gestione degli Errori

### Errori di Validazione

```ruby
def create
  user = User.new(user_params)

  if user.save
    render json: UserSerializer.new(user), status: :created
  else
    # Serializzazione automatica degli errori
    render json: PanStuff::Serializer::ResourceErrorsSerializer.new(user.errors),
           status: :unprocessable_entity
  end
end

# Risposta di errore:
# {
#   "errors": [
#     "Email non può essere vuoto",
#     "Nome è troppo corto (minimo 3 caratteri)"
#   ],
#   "details": {
#     "email": [{ "error": "blank" }],
#     "name": [{ "error": "tooShort", "count": 3 }]
#   }
# }
```

### Eccezioni Personalizzate

```ruby
def activate_user
  user = User.find(params[:id])

  unless user.can_be_activated?
    serializer = PanStuff::Serializer::ExceptionSerializer.new(
      status: 422,
      error: "L'utente non può essere attivato in questo stato",
      exception: "UserActivationError"
    )
    render json: serializer, status: :unprocessable_entity
    return
  end

  user.activate!
  render json: PanStuff::Serializer::ValidationResponseSerializer.new(
    user, "Utente attivato con successo"
  )
end
```

## Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :users do
        member do
          patch :activate
          patch :deactivate
        end
      end

      resources :products
      resources :orders

      get :dashboard, to: 'dashboard#index'
    end
  end
end
```

## Testing

### RSpec Setup

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  # Helper per testare risposte JSON
  config.include Module.new {
    def json_response
      JSON.parse(response.body, symbolize_names: true)
    end

    def expect_successful_response(expected_status = :ok)
      expect(response).to have_http_status(expected_status)
      expect(json_response).to have_key(:data)
    end

    def expect_error_response(expected_status = :unprocessable_entity)
      expect(response).to have_http_status(expected_status)
      expect(json_response).to have_key(:errors)
    end
  }
end
```

### Test di Controller

```ruby
# spec/controllers/api/users_controller_spec.rb
RSpec.describe Api::UsersController, type: :controller do
  describe 'GET #index' do
    let!(:users) { create_list(:user, 3) }

    it 'restituisce la lista degli utenti' do
      get :index

      expect_successful_response
      expect(json_response[:data]).to be_an(Array)
      expect(json_response[:data].length).to eq(3)
    end

    it 'supporta la paginazione' do
      get :index, params: { page: 1, per_page: 2 }

      expect_successful_response
      expect(json_response[:pagination]).to include(
        total_count: 3,
        current_page: 1,
        items_per_page: 2
      )
    end
  end

  describe 'POST #create' do
    let(:valid_params) { { user: attributes_for(:user) } }

    it 'crea un nuovo utente' do
      expect {
        post :create, params: valid_params
      }.to change(User, :count).by(1)

      expect_successful_response(:created)
    end

    it 'restituisce errori per parametri non validi' do
      post :create, params: { user: { name: '' } }

      expect_error_response
      expect(json_response[:errors]).to include('Nome non può essere vuoto')
    end
  end
end
```

## Prossimi Passi

1. **Esplora la Documentazione**: Leggi la documentazione dettagliata di ogni componente
2. **Personalizza i Serializzatori**: Crea serializzatori specifici per le tue esigenze
3. **Implementa Filtri Avanzati**: Usa ParamsHelpers per filtri complessi
4. **Ottimizza le Performance**: Implementa caching e ottimizzazioni database
5. **Testa Tutto**: Scrivi test completi per i tuoi endpoint

## Risorse Utili

- [ResourcesController](controllers/resources-controller.md) - Controller base per CRUD
- [ObjectSerializer](serializers/object-serializer.md) - Serializzazione avanzata
- [ActiveRecordPagination](pagination/active-record-pagination.md) - Paginazione efficiente
- [ParamsHelpers](helpers/params-helpers.md) - Gestione parametri
- [Esempi Avanzati](examples/advanced-serialization.md) - Tecniche avanzate
