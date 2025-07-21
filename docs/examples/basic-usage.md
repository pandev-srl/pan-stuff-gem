# Esempi di Utilizzo Base

Questa sezione fornisce esempi pratici per iniziare rapidamente con PanStuff, coprendo i casi d'uso più comuni.

## Setup Iniziale

### Gemfile

```ruby
# Gemfile
gem 'pan_stuff'
gem 'money-rails' # Se usi MoneySerializer
```

### Controller Base

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include PanStuff::ParamsHelpers

  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error

  private

  def handle_not_found(exception)
    render json: PanStuff::Serializer::ExceptionSerializer.new(
      status: 404,
      error: "Risorsa non trovata"
    ), status: :not_found
  end

  def handle_validation_error(exception)
    render json: PanStuff::Serializer::ResourceErrorsSerializer.new(
      exception.record.errors
    ), status: :unprocessable_entity
  end
end
```

## Esempio 1: API Semplice per Utenti

### Modello

```ruby
# app/models/user.rb
class User < ApplicationRecord
  include PanStuff::ActiveRecordPagination

  validates :name, presence: true, length: { minimum: 2 }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :active, -> { where(active: true) }
  scope :search, ->(term) { where('name ILIKE ? OR email ILIKE ?', "%#{term}%", "%#{term}%") }
end
```

### Serializzatore

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

### Controller

```ruby
# app/controllers/users_controller.rb
class UsersController < ApplicationController
  def index
    filters = query_params

    users = User.all
    users = users.active if filters[:active] == 'true'
    users = users.search(filters[:search]) if filters[:search].present?

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
    user_data = request_params[:user]
    user = User.new(user_data)

    if user.save
      render json: UserSerializer.new(user), status: :created
    else
      render json: PanStuff::Serializer::ResourceErrorsSerializer.new(user.errors),
             status: :unprocessable_entity
    end
  end

  def update
    user = User.find(params[:id])
    user_data = request_params[:user]

    if user.update(user_data)
      render json: UserSerializer.new(user)
    else
      render json: PanStuff::Serializer::ResourceErrorsSerializer.new(user.errors),
             status: :unprocessable_entity
    end
  end

  def destroy
    user = User.find(params[:id])
    user.destroy!

    render json: PanStuff::Serializer::ValidationResponseSerializer.new(
      user, "Utente eliminato con successo"
    )
  end
end
```

### Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  resources :users
end
```

### Esempi di Richieste

```bash
# GET /users - Lista utenti
curl "http://localhost:3000/users"

# GET /users?search=john&active=true&page=1&per_page=10 - Ricerca con filtri
curl "http://localhost:3000/users?search=john&active=true&page=1&per_page=10"

# GET /users/1 - Singolo utente
curl "http://localhost:3000/users/1"

# POST /users - Crea utente
curl -X POST "http://localhost:3000/users" \
  -H "Content-Type: application/json" \
  -d '{"user": {"name": "John Doe", "email": "john@example.com"}}'

# PUT /users/1 - Aggiorna utente
curl -X PUT "http://localhost:3000/users/1" \
  -H "Content-Type: application/json" \
  -d '{"user": {"name": "John Smith"}}'

# DELETE /users/1 - Elimina utente
curl -X DELETE "http://localhost:3000/users/1"
```

## Esempio 2: API E-commerce con Prodotti

### Modelli

```ruby
# app/models/category.rb
class Category < ApplicationRecord
  has_many :products
  validates :name, presence: true, uniqueness: true
end

# app/models/product.rb
class Product < ApplicationRecord
  include PanStuff::ActiveRecordPagination

  belongs_to :category

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :category, presence: true

  scope :by_category, ->(category_id) { where(category_id: category_id) }
  scope :price_range, ->(min, max) { where(price: min..max) }
  scope :search, ->(term) { where('name ILIKE ? OR description ILIKE ?', "%#{term}%", "%#{term}%") }
end
```

### Serializzatori

```ruby
# app/serializers/category_serializer.rb
class CategorySerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :description
end

# app/serializers/product_serializer.rb
class ProductSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :description
  attribute :price
  attribute :category, serializer: CategorySerializer
  attribute :created_at
  attribute :updated_at
end
```

### Controller

```ruby
# app/controllers/products_controller.rb
class ProductsController < ApplicationController
  def index
    filters = query_params

    products = Product.includes(:category)

    # Applica filtri
    products = products.by_category(filters[:category_id]) if filters[:category_id].present?
    products = products.search(filters[:search]) if filters[:search].present?

    if filters[:min_price].present? || filters[:max_price].present?
      min_price = filters[:min_price]&.to_f || 0
      max_price = filters[:max_price]&.to_f || Float::INFINITY
      products = products.price_range(min_price, max_price)
    end

    # Ordinamento
    case filters[:sort_by]
    when 'price'
      products = products.order(:price)
    when 'name'
      products = products.order(:name)
    else
      products = products.order(:created_at)
    end

    products = products.order(:desc) if filters[:sort_direction] == 'desc'

    # Paginazione
    paginated_products, metadata = products.paginate(
      current_page: filters[:page]&.to_i || 1,
      items_per_page: filters[:per_page]&.to_i || 12
    )

    render json: {
      data: ProductSerializer.new(paginated_products).to_h[:data],
      pagination: metadata,
      filters: {
        category_id: filters[:category_id],
        search: filters[:search],
        min_price: filters[:min_price],
        max_price: filters[:max_price],
        sort_by: filters[:sort_by],
        sort_direction: filters[:sort_direction]
      }
    }
  end

  def show
    product = Product.includes(:category).find(params[:id])
    render json: ProductSerializer.new(product)
  end

  def create
    product_data = request_params[:product]
    product = Product.new(product_data)

    if product.save
      render json: ProductSerializer.new(product), status: :created
    else
      render json: PanStuff::Serializer::ResourceErrorsSerializer.new(product.errors),
             status: :unprocessable_entity
    end
  end
end
```

### Esempi di Richieste

```bash
# GET /products - Tutti i prodotti
curl "http://localhost:3000/products"

# GET /products?category_id=1&min_price=10&max_price=100&sort_by=price
curl "http://localhost:3000/products?category_id=1&min_price=10&max_price=100&sort_by=price"

# POST /products - Crea prodotto
curl -X POST "http://localhost:3000/products" \
  -H "Content-Type: application/json" \
  -d '{
    "product": {
      "name": "Laptop Gaming",
      "description": "Laptop ad alte prestazioni",
      "price": 1299.99,
      "category_id": 1
    }
  }'
```

## Esempio 3: Dashboard con Statistiche

### Controller Dashboard

```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def index
    stats = calculate_stats
    render json: PanStuff::Serializer::HashSerializer.new(stats)
  end

  def users_stats
    stats = {
      total_users: User.count,
      active_users: User.active.count,
      new_users_today: User.where(created_at: Date.current.all_day).count,
      new_users_this_week: User.where(created_at: 1.week.ago..Time.current).count,
      new_users_this_month: User.where(created_at: 1.month.ago..Time.current).count
    }

    render json: PanStuff::Serializer::HashSerializer.new(stats)
  end

  def products_stats
    stats = {
      total_products: Product.count,
      products_by_category: products_by_category_stats,
      average_price: Product.average(:price)&.to_f&.round(2),
      price_range: {
        min: Product.minimum(:price),
        max: Product.maximum(:price)
      }
    }

    render json: PanStuff::Serializer::HashSerializer.new(stats)
  end

  private

  def calculate_stats
    {
      users: {
        total: User.count,
        active: User.active.count
      },
      products: {
        total: Product.count,
        categories: Category.count
      },
      summary: {
        generated_at: Time.current.iso8601,
        version: "1.0"
      }
    }
  end

  def products_by_category_stats
    Category.joins(:products)
            .group('categories.name')
            .count
  end
end
```

### Routes per Dashboard

```ruby
# config/routes.rb
Rails.application.routes.draw do
  resources :users
  resources :products

  get 'dashboard', to: 'dashboard#index'
  get 'dashboard/users', to: 'dashboard#users_stats'
  get 'dashboard/products', to: 'dashboard#products_stats'
end
```

## Esempio 4: Gestione Errori Avanzata

### Controller con Gestione Errori Personalizzata

```ruby
# app/controllers/advanced_users_controller.rb
class AdvancedUsersController < ApplicationController
  def activate
    user = User.find(params[:id])

    unless user.can_be_activated?
      render json: PanStuff::Serializer::ExceptionSerializer.new(
        status: 422,
        error: "L'utente non può essere attivato. Stato attuale: #{user.status}",
        exception: "UserActivationError"
      ), status: :unprocessable_entity
      return
    end

    user.update!(active: true)

    render json: PanStuff::Serializer::ValidationResponseSerializer.new(
      user, "Utente attivato con successo"
    )
  end

  def bulk_update
    user_ids = request_params[:user_ids]
    action = request_params[:action]

    unless %w[activate deactivate].include?(action)
      render json: PanStuff::Serializer::ExceptionSerializer.new(
        status: 400,
        error: "Azione non valida. Azioni supportate: activate, deactivate",
        exception: "InvalidActionError"
      ), status: :bad_request
      return
    end

    results = process_bulk_action(user_ids, action)

    response_data = PanStuff::Serializer::ValidationResponse.new(
      id: SecureRandom.uuid,
      status: results[:errors].empty? ? 200 : 207,
      message: "Processati #{user_ids.count} utenti"
    )

    # Aggiungi risultati dettagliati
    response_data.define_singleton_method(:successful) { results[:successful] }
    response_data.define_singleton_method(:failed) { results[:errors] }

    render json: PanStuff::Serializer::ValidationResponseSerializer.new(response_data)
  end

  private

  def process_bulk_action(user_ids, action)
    successful = []
    errors = []

    user_ids.each do |id|
      begin
        user = User.find(id)

        case action
        when 'activate'
          user.update!(active: true)
        when 'deactivate'
          user.update!(active: false)
        end

        successful << { id: user.id, name: user.name }
      rescue ActiveRecord::RecordNotFound
        errors << { id: id, error: "Utente non trovato" }
      rescue ActiveRecord::RecordInvalid => e
        errors << { id: id, error: e.message }
      end
    end

    { successful: successful, errors: errors }
  end
end
```

## Esempio 5: Testing

### Test RSpec

```ruby
# spec/controllers/users_controller_spec.rb
require 'rails_helper'

RSpec.describe UsersController, type: :controller do
  let(:valid_attributes) { { name: 'John Doe', email: 'john@example.com' } }
  let(:invalid_attributes) { { name: '', email: 'invalid-email' } }

  describe 'GET #index' do
    let!(:users) { create_list(:user, 5) }

    it 'returns a successful response' do
      get :index
      expect(response).to be_successful
    end

    it 'returns users data' do
      get :index
      json = JSON.parse(response.body, symbolize_names: true)

      expect(json).to have_key(:data)
      expect(json[:data]).to be_an(Array)
      expect(json[:data].length).to eq(5)
    end

    it 'supports pagination' do
      get :index, params: { page: 1, per_page: 3 }
      json = JSON.parse(response.body, symbolize_names: true)

      expect(json[:pagination]).to include(
        total_count: 5,
        current_page: 1,
        items_per_page: 3,
        total_pages: 2
      )
    end

    it 'supports search' do
      user = create(:user, name: 'Special User')
      get :index, params: { search: 'Special' }
      json = JSON.parse(response.body, symbolize_names: true)

      expect(json[:data].length).to eq(1)
      expect(json[:data].first[:name]).to eq('Special User')
    end
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      it 'creates a new user' do
        expect {
          post :create, params: { user: valid_attributes }
        }.to change(User, :count).by(1)
      end

      it 'returns created status' do
        post :create, params: { user: valid_attributes }
        expect(response).to have_http_status(:created)
      end

      it 'returns the created user' do
        post :create, params: { user: valid_attributes }
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:data][:name]).to eq('John Doe')
        expect(json[:data][:email]).to eq('john@example.com')
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new user' do
        expect {
          post :create, params: { user: invalid_attributes }
        }.not_to change(User, :count)
      end

      it 'returns unprocessable entity status' do
        post :create, params: { user: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error details' do
        post :create, params: { user: invalid_attributes }
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json).to have_key(:errors)
        expect(json).to have_key(:details)
        expect(json[:errors]).to include('Nome non può essere vuoto')
      end
    end
  end
end
```

### Factory per Testing

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "User #{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    active { true }

    trait :inactive do
      active { false }
    end

    trait :with_company do
      association :company
    end
  end
end

# spec/factories/products.rb
FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "Product #{n}" }
    description { "A great product" }
    price { rand(10.0..1000.0).round(2) }
    association :category
  end
end
```

Questi esempi forniscono una base solida per iniziare a utilizzare PanStuff nelle tue applicazioni Rails, coprendo i casi d'uso più comuni e fornendo pattern riutilizzabili.
