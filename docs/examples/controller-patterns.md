# Pattern per Controller

Questa guida presenta pattern comuni e best practices per l'utilizzo di PanStuff nei controller Rails, con esempi pratici e soluzioni a problemi frequenti.

## Pattern Base

### Controller CRUD Standardizzato

```ruby
class BaseApiController < ApplicationController
  include PanStuff::ParamsHelpers

  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
  rescue_from ActionController::ParameterMissing, with: :handle_missing_params

  private

  def handle_standard_error(exception)
    Rails.logger.error "Errore interno: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    render json: PanStuff::Serializer::ExceptionSerializer.new(
      status: 500,
      error: "Si è verificato un errore interno del server"
    ), status: :internal_server_error
  end

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

  def handle_missing_params(exception)
    render json: PanStuff::Serializer::ExceptionSerializer.new(
      status: 400,
      error: "Parametro richiesto mancante: #{exception.param}"
    ), status: :bad_request
  end
end
```

### Controller con ResourcesController

```ruby
class UsersController < BaseApiController
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

  def set_context
    self.context = {
      current_user: current_user,
      permissions: current_user.permissions,
      include_sensitive_data: current_user.admin?
    }
  end

  def resource_collection_resolver
    users = User.includes(:company, :roles)
    users = apply_filters(users)
    users = apply_sorting(users)
    apply_pagination(users)
  end

  def apply_filters(relation)
    filters = query_params

    relation = relation.where(active: true) if filters[:active] == 'true'
    relation = relation.where('name ILIKE ?', "%#{filters[:search]}%") if filters[:search].present?
    relation = relation.where(company_id: filters[:company_id]) if filters[:company_id].present?
    relation = relation.where(role: filters[:role]) if filters[:role].present?

    if filters[:created_after].present?
      relation = relation.where('created_at >= ?', Date.parse(filters[:created_after]))
    end

    relation
  end

  def apply_sorting(relation)
    filters = query_params
    sort_by = filters[:sort_by] || 'created_at'
    sort_direction = filters[:sort_direction] == 'desc' ? :desc : :asc

    case sort_by
    when 'name', 'email', 'created_at', 'updated_at'
      relation.order(sort_by => sort_direction)
    else
      relation.order(created_at: :desc)
    end
  end

  def apply_pagination(relation)
    filters = query_params
    current_page = [filters[:page]&.to_i || 1, 1].max
    items_per_page = [[filters[:per_page]&.to_i || 20, 1].max, 100].min

    paginated_relation, metadata = relation.paginate(
      current_page: current_page,
      items_per_page: items_per_page
    )

    add_meta(:pagination, metadata)
    add_meta(:filters, filters.slice(:search, :active, :company_id, :role))

    paginated_relation
  end
end
```

## Pattern Avanzati

### Controller con Azioni Personalizzate

```ruby
class UsersController < BaseApiController
  include PanStuff::ResourcesController

  # Azioni personalizzate oltre al CRUD standard
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

    user.activate!

    render json: PanStuff::Serializer::ValidationResponseSerializer.new(
      user, "Utente attivato con successo"
    )
  end

  def bulk_operations
    operation = request_params[:operation]
    user_ids = request_params[:user_ids]

    case operation
    when 'activate'
      result = bulk_activate(user_ids)
    when 'deactivate'
      result = bulk_deactivate(user_ids)
    when 'delete'
      result = bulk_delete(user_ids)
    else
      render json: PanStuff::Serializer::ExceptionSerializer.new(
        status: 400,
        error: "Operazione non supportata: #{operation}"
      ), status: :bad_request
      return
    end

    render json: PanStuff::Serializer::HashSerializer.new(result)
  end

  def export
    format = params[:format] || 'csv'
    filters = query_params

    users = User.includes(:company)
    users = apply_filters(users)

    case format
    when 'csv'
      csv_data = UserExportService.new(users).to_csv
      send_data csv_data, filename: "users_#{Date.current}.csv", type: 'text/csv'
    when 'json'
      render json: PanStuff::Serializer::HashSerializer.new({
        users: UserSerializer.new(users, root: false).to_h,
        exported_at: Time.current.iso8601,
        total_count: users.count
      })
    else
      render json: PanStuff::Serializer::ExceptionSerializer.new(
        status: 400,
        error: "Formato non supportato: #{format}"
      ), status: :bad_request
    end
  end

  private

  def bulk_activate(user_ids)
    successful = []
    failed = []

    User.where(id: user_ids).find_each do |user|
      if user.can_be_activated? && user.activate!
        successful << { id: user.id, name: user.name }
      else
        failed << { id: user.id, name: user.name, errors: user.errors.full_messages }
      end
    end

    {
      operation: 'activate',
      successful: successful,
      failed: failed,
      summary: {
        total: user_ids.count,
        successful_count: successful.count,
        failed_count: failed.count
      }
    }
  end
end
```

### Controller con Validazione Avanzata

```ruby
class ProductsController < BaseApiController
  before_action :validate_create_params, only: [:create]
  before_action :validate_search_params, only: [:index]

  def index
    products = Product.includes(:category, :reviews)
    products = apply_search_filters(products)
    products = apply_sorting(products)

    paginated_products, metadata = products.paginate(
      current_page: search_params[:page] || 1,
      items_per_page: search_params[:per_page] || 12
    )

    render json: {
      data: ProductSerializer.new(paginated_products).to_h[:data],
      pagination: metadata,
      facets: calculate_facets(products.unscope(:limit, :offset))
    }
  end

  def create
    product = Product.new(product_params)

    if product.save
      # Trigger background jobs
      ProductIndexingJob.perform_later(product.id)
      ProductNotificationJob.perform_later(product.id, 'created')

      render json: ProductSerializer.new(product), status: :created
    else
      render json: PanStuff::Serializer::ResourceErrorsSerializer.new(product.errors),
             status: :unprocessable_entity
    end
  end

  def recommendations
    product = Product.find(params[:id])
    user = current_user

    recommendations = RecommendationService.new(product, user).generate

    render json: PanStuff::Serializer::HashSerializer.new({
      product_id: product.id,
      recommendations: ProductSerializer.new(recommendations, root: false).to_h,
      algorithm: 'collaborative_filtering',
      generated_at: Time.current.iso8601
    })
  end

  private

  def validate_create_params
    validator = ProductParamsValidator.new(request_params[:product])

    unless validator.valid?
      render json: PanStuff::Serializer::ResourceErrorsSerializer.new(validator.errors),
             status: :bad_request
      return
    end
  end

  def validate_search_params
    @search_params = SearchParamsValidator.new(query_params)

    unless @search_params.valid?
      render json: PanStuff::Serializer::ExceptionSerializer.new(
        status: 400,
        error: "Parametri di ricerca non validi: #{@search_params.errors.full_messages.join(', ')}"
      ), status: :bad_request
      return
    end
  end

  def search_params
    @search_params.to_h
  end

  def product_params
    request_params[:product].permit(:name, :description, :price, :category_id, :sku, images: [], tags: [])
  end

  def apply_search_filters(relation)
    params = search_params

    relation = relation.where('name ILIKE ? OR description ILIKE ?', "%#{params[:q]}%", "%#{params[:q]}%") if params[:q].present?
    relation = relation.where(category_id: params[:category_id]) if params[:category_id].present?
    relation = relation.where('price >= ?', params[:min_price]) if params[:min_price].present?
    relation = relation.where('price <= ?', params[:max_price]) if params[:max_price].present?
    relation = relation.joins(:reviews).where('reviews.rating >= ?', params[:min_rating]) if params[:min_rating].present?

    relation
  end

  def calculate_facets(relation)
    {
      categories: relation.joins(:category).group('categories.name').count,
      price_ranges: {
        '0-50' => relation.where(price: 0..50).count,
        '51-100' => relation.where(price: 51..100).count,
        '101-200' => relation.where(price: 101..200).count,
        '200+' => relation.where('price > 200').count
      },
      ratings: relation.joins(:reviews).group('FLOOR(reviews.rating)').count
    }
  end
end
```

### Controller con Caching Intelligente

```ruby
class CachedProductsController < BaseApiController
  before_action :set_cache_headers

  def index
    cache_key = generate_cache_key

    cached_response = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      products = Product.includes(:category, :reviews)
      products = apply_filters(products)

      paginated_products, metadata = products.paginate(
        current_page: params[:page]&.to_i || 1,
        items_per_page: params[:per_page]&.to_i || 12
      )

      {
        data: ProductSerializer.new(paginated_products).to_h[:data],
        pagination: metadata,
        cached_at: Time.current.iso8601
      }
    end

    render json: cached_response
  end

  def show
    product = Product.find(params[:id])

    # Cache per singolo prodotto con invalidazione automatica
    cached_product = Rails.cache.fetch("product_#{product.id}_#{product.updated_at.to_i}", expires_in: 1.hour) do
      ProductDetailSerializer.new(product).to_h
    end

    render json: cached_product
  end

  def trending
    # Cache per prodotti trending con TTL breve
    trending_products = Rails.cache.fetch('trending_products', expires_in: 5.minutes) do
      products = Product.joins(:order_items)
                       .where(order_items: { created_at: 7.days.ago..Time.current })
                       .group('products.id')
                       .order('COUNT(order_items.id) DESC')
                       .limit(10)

      ProductSerializer.new(products).to_h
    end

    render json: trending_products
  end

  private

  def generate_cache_key
    filter_params = params.slice(:category_id, :min_price, :max_price, :search, :page, :per_page)
    "products_index_#{Digest::MD5.hexdigest(filter_params.to_query)}"
  end

  def set_cache_headers
    expires_in 15.minutes, public: true
    fresh_when(etag: generate_cache_key, last_modified: Product.maximum(:updated_at))
  end
end
```

## Pattern per API Versioning

### Controller con Versioning

```ruby
module Api
  module V1
    class BaseController < ApplicationController
      include PanStuff::ParamsHelpers

      before_action :set_api_version

      private

      def set_api_version
        response.headers['API-Version'] = '1.0'
      end
    end

    class UsersController < BaseController
      def index
        users = User.includes(:company)
        render json: V1::UserSerializer.new(users)
      end
    end
  end

  module V2
    class BaseController < ApplicationController
      include PanStuff::ParamsHelpers

      before_action :set_api_version

      private

      def set_api_version
        response.headers['API-Version'] = '2.0'
      end
    end

    class UsersController < BaseController
      def index
        users = User.includes(:company, :roles, :permissions)

        # V2 include più dati e supporta filtri avanzati
        users = apply_v2_filters(users)

        paginated_users, metadata = users.paginate(
          current_page: params[:page]&.to_i || 1,
          items_per_page: params[:per_page]&.to_i || 20
        )

        render json: {
          users: V2::UserSerializer.new(paginated_users).to_h[:data],
          pagination: V2::PaginationSerializer.new(metadata).to_h,
          api_version: '2.0'
        }
      end

      private

      def apply_v2_filters(relation)
        filters = query_params

        # V2 supporta filtri più avanzati
        relation = relation.where(active: filters[:active]) if filters[:active].present?
        relation = relation.joins(:roles).where(roles: { name: filters[:role] }) if filters[:role].present?
        relation = relation.where('created_at >= ?', filters[:created_after]) if filters[:created_after].present?

        # Filtro per permessi (solo in V2)
        if filters[:has_permission].present?
          relation = relation.joins(:permissions).where(permissions: { name: filters[:has_permission] })
        end

        relation
      end
    end
  end
end
```

## Pattern per Autenticazione e Autorizzazione

### Controller con Autorizzazione Granulare

```ruby
class SecureUsersController < BaseApiController
  include PanStuff::ResourcesController

  before_action :authenticate_user!
  before_action :authorize_action!

  private

  def authorize_action!
    case action_name
    when 'index'
      authorize_index
    when 'show'
      authorize_show
    when 'create'
      authorize_create
    when 'update'
      authorize_update
    when 'destroy'
      authorize_destroy
    end
  end

  def authorize_index
    unless current_user.can_list_users?
      render_forbidden("Non hai i permessi per visualizzare la lista utenti")
    end
  end

  def authorize_show
    user = User.find(params[:id])

    unless current_user.can_view_user?(user)
      render_forbidden("Non hai i permessi per visualizzare questo utente")
    end
  end

  def authorize_create
    unless current_user.can_create_users?
      render_forbidden("Non hai i permessi per creare utenti")
    end
  end

  def authorize_update
    user = User.find(params[:id])

    unless current_user.can_edit_user?(user)
      render_forbidden("Non hai i permessi per modificare questo utente")
    end
  end

  def authorize_destroy
    user = User.find(params[:id])

    unless current_user.can_delete_user?(user)
      render_forbidden("Non hai i permessi per eliminare questo utente")
    end
  end

  def render_forbidden(message)
    render json: PanStuff::Serializer::ExceptionSerializer.new(
      status: 403,
      error: message,
      exception: "ForbiddenError"
    ), status: :forbidden
  end

  def set_context
    self.context = {
      current_user: current_user,
      permissions: current_user.permissions.pluck(:name),
      can_view_sensitive_data: current_user.admin? || current_user.hr?
    }
  end
end
```

## Pattern per Testing

### Test Helper per Controller

```ruby
# spec/support/controller_helpers.rb
module ControllerHelpers
  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  def expect_successful_response(expected_status = :ok)
    expect(response).to have_http_status(expected_status)
    expect(json_response).to have_key(:data)
  end

  def expect_error_response(expected_status = :unprocessable_entity)
    expect(response).to have_http_status(expected_status)
    expect(json_response).to have_key(:errors) | have_key(:validationResponse)
  end

  def expect_paginated_response
    expect(json_response).to have_key(:pagination)
    expect(json_response[:pagination]).to include(:total_count, :current_page, :items_per_page)
  end

  def authenticate_as(user)
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:authenticate_user!).and_return(true)
  end
end

RSpec.configure do |config|
  config.include ControllerHelpers, type: :controller
end
```

### Test per Controller Pattern

```ruby
# spec/controllers/users_controller_spec.rb
RSpec.describe UsersController, type: :controller do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  describe 'GET #index' do
    let!(:users) { create_list(:user, 5) }

    context 'when authenticated as admin' do
      before { authenticate_as(admin) }

      it 'returns all users' do
        get :index
        expect_successful_response
        expect(json_response[:data].length).to eq(5)
      end

      it 'supports filtering' do
        active_user = create(:user, active: true)
        inactive_user = create(:user, active: false)

        get :index, params: { active: 'true' }
        expect_successful_response

        returned_ids = json_response[:data].map { |u| u[:id] }
        expect(returned_ids).to include(active_user.id)
        expect(returned_ids).not_to include(inactive_user.id)
      end

      it 'supports pagination' do
        get :index, params: { page: 1, per_page: 3 }
        expect_successful_response
        expect_paginated_response

        expect(json_response[:pagination][:total_count]).to eq(5)
        expect(json_response[:pagination][:current_page]).to eq(1)
        expect(json_response[:data].length).to eq(3)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST #bulk_operations' do
    let!(:users) { create_list(:user, 3) }

    before { authenticate_as(admin) }

    it 'activates multiple users' do
      post :bulk_operations, params: {
        operation: 'activate',
        user_ids: users.map(&:id)
      }

      expect_successful_response
      expect(json_response[:data][:successful]).to be_an(Array)
      expect(json_response[:data][:successful].length).to eq(3)
    end

    it 'handles invalid operation' do
      post :bulk_operations, params: {
        operation: 'invalid_operation',
        user_ids: users.map(&:id)
      }

      expect(response).to have_http_status(:bad_request)
      expect(json_response[:validationResponse][:error]).to include('non supportata')
    end
  end
end
```

Questi pattern forniscono una base solida per costruire API robuste e scalabili con PanStuff, coprendo casi d'uso comuni e best practices consolidate.
