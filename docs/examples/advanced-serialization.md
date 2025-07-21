# Serializzazione Avanzata

Questa guida copre tecniche avanzate di serializzazione con PanStuff, inclusi pattern complessi, ottimizzazioni e casi d'uso specializzati.

## Serializzatori Condizionali Avanzati

### Serializzazione Basata su Ruoli Utente

```ruby
class UserSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :email
  attribute :phone, serialize_if: ->(context) { can_view_phone?(context) }
  attribute :admin_notes, serialize_if: ->(context) { context[:current_user]&.admin? }
  attribute :salary, serialize_if: ->(context) { can_view_salary?(context) }
  attribute :permissions, method: :user_permissions, serialize_if: ->(context) { context[:include_permissions] }

  private

  def self.can_view_phone?(context)
    current_user = context[:current_user]
    return false unless current_user

    current_user.admin? || current_user.hr? || context[:show_contact_info]
  end

  def self.can_view_salary?(context)
    current_user = context[:current_user]
    return false unless current_user

    current_user.admin? || (current_user.hr? && context[:department] == 'hr')
  end

  def user_permissions(user)
    return [] unless context[:current_user]&.admin?

    user.roles.map(&:name)
  end
end

# Utilizzo nel controller
def show
  user = User.find(params[:id])

  context = {
    current_user: current_user,
    show_contact_info: params[:include_contact] == 'true',
    include_permissions: params[:include_permissions] == 'true',
    department: current_user.department
  }

  render json: UserSerializer.new(user, context: context)
end
```

### Serializzazione Multi-Versione API

```ruby
module Api
  module V1
    class UserSerializer
      include PanStuff::Serializer::ObjectSerializer

      attribute :id
      attribute :name
      attribute :email
      attribute :created_at
    end
  end

  module V2
    class UserSerializer
      include PanStuff::Serializer::ObjectSerializer

      attribute :id
      attribute :full_name, method: :name  # Rinominato in v2
      attribute :email_address, method: :email  # Rinominato in v2
      attribute :profile, method: :user_profile
      attribute :metadata, method: :user_metadata
      attribute :created_at
      attribute :updated_at  # Aggiunto in v2

      private

      def user_profile(user)
        {
          avatar_url: user.avatar.present? ? user.avatar.url : nil,
          bio: user.bio,
          location: user.location
        }
      end

      def user_metadata(user)
        {
          last_login: user.last_login_at,
          login_count: user.sign_in_count,
          verified: user.email_verified?
        }
      end
    end
  end
end

# Controller con versioning
class Api::UsersController < ApplicationController
  def show
    user = User.find(params[:id])

    serializer_class = case request.headers['API-Version']
                      when '2.0'
                        Api::V2::UserSerializer
                      else
                        Api::V1::UserSerializer
                      end

    render json: serializer_class.new(user)
  end
end
```

## Serializzatori Annidati Complessi

### Serializzazione di Strutture Gerarchiche

```ruby
class OrganizationSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :departments, serializer: DepartmentSerializer
  attribute :stats, method: :organization_stats

  private

  def organization_stats(org)
    {
      total_employees: org.users.count,
      departments_count: org.departments.count,
      active_projects: org.projects.active.count
    }
  end
end

class DepartmentSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :manager, serializer: UserSerializer
  attribute :employees, serializer: UserSerializer
  attribute :projects, serializer: ProjectSerializer, serialize_if: ->(context) { context[:include_projects] }
  attribute :budget, serializer: PanStuff::Serializer::MoneySerializer, serialize_if: ->(context) { context[:include_budget] }

  # Evita serializzazione ricorsiva
  def initialize(resource, **options)
    super(resource, **options.merge(context: options[:context]&.merge(depth: (options[:context][:depth] || 0) + 1)))
  end
end

class ProjectSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :status
  attribute :team_members, serializer: UserSerializer, serialize_if: ->(context) { (context[:depth] || 0) < 3 }
  attribute :budget, serializer: PanStuff::Serializer::MoneySerializer
end
```

### Serializzazione con Aggregazioni Dinamiche

```ruby
class ProductAnalyticsSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :price, serializer: PanStuff::Serializer::MoneySerializer
  attribute :sales_data, method: :calculate_sales_data
  attribute :performance_metrics, method: :calculate_performance
  attribute :recommendations, method: :get_recommendations

  private

  def calculate_sales_data(product)
    period = context[:period] || 30.days

    {
      total_sales: product.orders.where(created_at: period.ago..Time.current).sum(:quantity),
      revenue: product.orders.where(created_at: period.ago..Time.current).sum(:total),
      average_order_value: product.orders.where(created_at: period.ago..Time.current).average(:total)&.to_f,
      conversion_rate: calculate_conversion_rate(product, period)
    }
  end

  def calculate_performance(product)
    {
      views: product.view_count,
      cart_additions: product.cart_addition_count,
      purchases: product.purchase_count,
      rating: product.average_rating,
      review_count: product.reviews.count
    }
  end

  def get_recommendations(product)
    return [] unless context[:include_recommendations]

    RecommendationEngine.new(product, context[:current_user]).generate
  end

  def calculate_conversion_rate(product, period)
    views = product.analytics.where(event: 'view', created_at: period.ago..Time.current).count
    purchases = product.analytics.where(event: 'purchase', created_at: period.ago..Time.current).count

    return 0 if views.zero?
    (purchases.to_f / views * 100).round(2)
  end
end
```

## Ottimizzazioni per Performance

### Serializzazione Lazy con Caching

```ruby
class OptimizedUserSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :email
  attribute :company, method: :cached_company
  attribute :recent_activity, method: :cached_recent_activity
  attribute :stats, method: :cached_user_stats

  private

  def cached_company(user)
    Rails.cache.fetch("user_company_#{user.id}_#{user.updated_at.to_i}", expires_in: 1.hour) do
      CompanySerializer.new(user.company, root: false).to_h if user.company
    end
  end

  def cached_recent_activity(user)
    cache_key = "user_activity_#{user.id}_#{Date.current}"

    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      user.activities.recent.limit(5).map do |activity|
        {
          type: activity.activity_type,
          description: activity.description,
          created_at: activity.created_at
        }
      end
    end
  end

  def cached_user_stats(user)
    Rails.cache.fetch("user_stats_#{user.id}", expires_in: 1.hour) do
      {
        total_orders: user.orders.count,
        total_spent: user.orders.sum(:total),
        favorite_category: user.most_purchased_category&.name,
        member_since: user.created_at.year
      }
    end
  end
end
```

### Serializzazione Batch per Performance

```ruby
class BatchUserSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :email
  attribute :company, method: :get_company
  attribute :order_count, method: :get_order_count
  attribute :total_spent, method: :get_total_spent

  def initialize(resource, **options)
    super(resource, **options)
    preload_associations if self.class.collection?(resource)
  end

  private

  def preload_associations
    # Precarica tutte le associazioni necessarie
    @companies = Company.where(id: @resource.map(&:company_id).compact).index_by(&:id)

    # Precarica statistiche in batch
    user_ids = @resource.map(&:id)
    @order_stats = Order.where(user_id: user_ids)
                       .group(:user_id)
                       .group('COUNT(*) as order_count, SUM(total) as total_spent')
                       .index_by(&:user_id)
  end

  def get_company(user)
    return nil unless user.company_id

    company = @companies ? @companies[user.company_id] : user.company
    CompanySerializer.new(company, root: false).to_h if company
  end

  def get_order_count(user)
    @order_stats ? @order_stats[user.id]&.order_count || 0 : user.orders.count
  end

  def get_total_spent(user)
    @order_stats ? @order_stats[user.id]&.total_spent || 0 : user.orders.sum(:total)
  end
end
```

## Pattern Avanzati

### Serializzatore con Trasformazioni Dinamiche

```ruby
class FlexibleDataSerializer
  include PanStuff::Serializer::ObjectSerializer

  def initialize(resource, **options)
    @field_config = options[:fields] || {}
    @transformations = options[:transformations] || {}
    super(resource, **options)

    setup_dynamic_attributes
  end

  private

  def setup_dynamic_attributes
    @field_config.each do |field_name, config|
      case config[:type]
      when 'money'
        self.class.attribute field_name, serializer: PanStuff::Serializer::MoneySerializer
      when 'date'
        self.class.attribute field_name, method: "format_#{field_name}"
        define_date_formatter(field_name, config[:format])
      when 'enum'
        self.class.attribute field_name, method: "humanize_#{field_name}"
        define_enum_humanizer(field_name, config[:values])
      else
        self.class.attribute field_name
      end
    end
  end

  def define_date_formatter(field_name, format)
    define_singleton_method("format_#{field_name}") do |record|
      date_value = record.send(field_name)
      return nil unless date_value

      case format
      when 'iso8601'
        date_value.iso8601
      when 'human'
        date_value.strftime('%d %B %Y')
      else
        date_value.strftime(format)
      end
    end
  end

  def define_enum_humanizer(field_name, values_map)
    define_singleton_method("humanize_#{field_name}") do |record|
      raw_value = record.send(field_name)
      values_map[raw_value] || raw_value
    end
  end
end

# Utilizzo
field_config = {
  created_at: { type: 'date', format: 'human' },
  price: { type: 'money' },
  status: { type: 'enum', values: { 'active' => 'Attivo', 'inactive' => 'Inattivo' } }
}

serializer = FlexibleDataSerializer.new(
  products,
  fields: field_config,
  transformations: { currency: 'EUR' }
)
```

### Serializzatore con Validazione Schema

```ruby
class ValidatedSerializer
  include PanStuff::Serializer::ObjectSerializer
  include ActiveModel::Validations

  attr_accessor :schema_version, :required_fields, :optional_fields

  validates :schema_version, presence: true, inclusion: { in: %w[1.0 2.0] }
  validate :validate_required_fields
  validate :validate_field_types

  def initialize(resource, **options)
    @schema_version = options[:schema_version] || '1.0'
    @required_fields = options[:required_fields] || []
    @optional_fields = options[:optional_fields] || []

    super(resource, **options)

    unless valid?
      raise ArgumentError, "Schema validation failed: #{errors.full_messages.join(', ')}"
    end
  end

  def serializable_hash!
    result = super

    # Aggiungi metadati dello schema
    if root
      result[:schema] = {
        version: schema_version,
        generated_at: Time.current.iso8601,
        fields: {
          required: required_fields,
          optional: optional_fields
        }
      }
    end

    result
  end

  private

  def validate_required_fields
    missing_fields = required_fields - self.class.attributes_to_serialize.map { |attr| attr[:name] }

    if missing_fields.any?
      errors.add(:required_fields, "Missing required fields: #{missing_fields.join(', ')}")
    end
  end

  def validate_field_types
    # Validazione personalizzata dei tipi di campo
    # Implementa la logica specifica per la tua applicazione
  end
end
```

## Integrazione con GraphQL

### Serializzatore Compatibile con GraphQL

```ruby
class GraphQLCompatibleSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :email
  attribute :posts, method: :get_posts, serialize_if: ->(context) { context[:include_posts] }
  attribute :comments, method: :get_comments, serialize_if: ->(context) { context[:include_comments] }

  def initialize(resource, **options)
    @graphql_info = options[:graphql_info]
    super(resource, **options)
  end

  private

  def get_posts(user)
    return [] unless should_include_field?(:posts)

    posts = user.posts
    posts = posts.limit(context[:posts_limit]) if context[:posts_limit]

    PostSerializer.new(posts, root: false, context: context).to_h
  end

  def get_comments(user)
    return [] unless should_include_field?(:comments)

    comments = user.comments.includes(:post)
    CommentSerializer.new(comments, root: false, context: context).to_h
  end

  def should_include_field?(field_name)
    return true unless @graphql_info

    # Logica per determinare se il campo è richiesto nella query GraphQL
    @graphql_info.selections.any? { |selection| selection.name == field_name.to_s }
  end
end
```

## Testing Avanzato

### Test per Serializzatori Complessi

```ruby
# spec/serializers/advanced_user_serializer_spec.rb
RSpec.describe AdvancedUserSerializer do
  let(:user) { create(:user, :with_company, :with_orders) }
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  describe 'conditional serialization' do
    context 'when current user is admin' do
      let(:context) { { current_user: admin, include_sensitive_data: true } }
      let(:serializer) { described_class.new(user, context: context) }
      let(:result) { serializer.to_h }

      it 'includes sensitive fields' do
        expect(result[:data]).to have_key(:salary)
        expect(result[:data]).to have_key(:admin_notes)
      end

      it 'includes permissions' do
        expect(result[:data]).to have_key(:permissions)
        expect(result[:data][:permissions]).to be_an(Array)
      end
    end

    context 'when current user is regular user' do
      let(:context) { { current_user: regular_user } }
      let(:serializer) { described_class.new(user, context: context) }
      let(:result) { serializer.to_h }

      it 'excludes sensitive fields' do
        expect(result[:data]).not_to have_key(:salary)
        expect(result[:data]).not_to have_key(:admin_notes)
      end
    end
  end

  describe 'performance' do
    let(:users) { create_list(:user, 100, :with_company) }
    let(:serializer) { described_class.new(users) }

    it 'serializes large collections efficiently' do
      expect {
        serializer.to_h
      }.to perform_under(500).ms
    end

    it 'does not cause N+1 queries' do
      expect {
        serializer.to_h
      }.to make_database_queries(count: 3) # Adjust based on your preloading strategy
    end
  end

  describe 'caching' do
    let(:serializer) { described_class.new(user) }

    it 'caches expensive computations' do
      expect(Rails.cache).to receive(:fetch).with(/user_stats_#{user.id}/).and_call_original

      serializer.to_h
    end
  end
end
```

Questi pattern avanzati ti permettono di gestire casi d'uso complessi mantenendo codice pulito e performante.
