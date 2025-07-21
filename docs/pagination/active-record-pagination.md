# ActiveRecordPagination

Il modulo `ActiveRecordPagination` estende i modelli ActiveRecord con funzionalità di paginazione semplice e efficiente, fornendo sia i dati paginati che i metadati necessari per l'interfaccia utente.

## Panoramica

ActiveRecordPagination fornisce:

- Paginazione semplice per modelli ActiveRecord
- Calcolo automatico dei metadati di paginazione
- Integrazione seamless con le query esistenti
- Performance ottimizzate con LIMIT e OFFSET
- Metadati completi per l'implementazione di UI di paginazione

## Installazione

Includi il modulo nel tuo modello ActiveRecord:

```ruby
class User < ApplicationRecord
  include PanStuff::ActiveRecordPagination
end
```

## Utilizzo Base

```ruby
# Paginazione semplice
users, metadata = User.paginate(current_page: 1, items_per_page: 10)

# users è una ActiveRecord::Relation con i record della pagina corrente
# metadata contiene informazioni sulla paginazione

puts users.count # => 10 (o meno se è l'ultima pagina)
puts metadata
# => {
#   total_count: 150,
#   total_pages: 15,
#   current_page: 1,
#   items_per_page: 10
# }
```

## Struttura dei Metadati

Il metodo `paginate` restituisce un array con due elementi:

1. **Collection paginata**: ActiveRecord::Relation con i record della pagina
2. **Metadata hash**: Informazioni sulla paginazione

### Metadati Disponibili

```ruby
metadata = {
  total_count: 150,      # Numero totale di record
  total_pages: 15,       # Numero totale di pagine
  current_page: 1,       # Pagina corrente
  items_per_page: 10     # Elementi per pagina
}
```

## Esempi Pratici

### Controller Base

```ruby
class UsersController < ApplicationController
  def index
    users, pagination_metadata = User.paginate(
      current_page: params[:page]&.to_i || 1,
      items_per_page: params[:per_page]&.to_i || 20
    )

    render json: {
      data: UserSerializer.new(users).to_h[:data],
      pagination: pagination_metadata
    }
  end
end
```

### Con Filtri e Ordinamento

```ruby
class ProductsController < ApplicationController
  def index
    # Applica filtri prima della paginazione
    products = Product.includes(:category)

    # Filtri
    products = products.where(category: params[:category]) if params[:category].present?
    products = products.where('name ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    products = products.where('price >= ?', params[:min_price]) if params[:min_price].present?

    # Ordinamento
    products = products.order(params[:sort] || :created_at)

    # Paginazione
    paginated_products, metadata = products.paginate(
      current_page: params[:page]&.to_i || 1,
      items_per_page: params[:per_page]&.to_i || 12
    )

    render json: {
      data: ProductSerializer.new(paginated_products).to_h[:data],
      pagination: metadata,
      filters: {
        category: params[:category],
        search: params[:search],
        min_price: params[:min_price],
        sort: params[:sort]
      }
    }
  end
end
```

### Con ResourcesController

```ruby
class UsersController < ApplicationController
  include PanStuff::ResourcesController

  private

  def resource_collection_resolver
    users = User.includes(:company)

    # Applica filtri se presenti
    users = apply_filters(users)

    # Paginazione
    paginated_users, pagination_metadata = users.paginate(
      current_page: params[:page]&.to_i || 1,
      items_per_page: params[:per_page]&.to_i || 20
    )

    # Aggiungi metadati di paginazione ai meta del controller
    add_meta(:pagination, pagination_metadata)

    paginated_users
  end

  def apply_filters(users)
    users = users.where(active: true) if params[:active] == 'true'
    users = users.where('name ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    users = users.where(company_id: params[:company_id]) if params[:company_id].present?
    users
  end
end
```

## Esempi Avanzati

### Paginazione con Aggregazioni

```ruby
class OrdersController < ApplicationController
  def index
    # Query base con join per aggregazioni
    orders = Order.joins(:order_items)
                  .select('orders.*, COUNT(order_items.id) as items_count, SUM(order_items.total) as order_total')
                  .group('orders.id')

    # Filtri
    orders = orders.where(status: params[:status]) if params[:status].present?
    orders = orders.where('orders.created_at >= ?', params[:from_date]) if params[:from_date].present?

    # Paginazione
    paginated_orders, metadata = orders.paginate(
      current_page: params[:page]&.to_i || 1,
      items_per_page: 15
    )

    render json: {
      data: paginated_orders.map do |order|
        {
          id: order.id,
          customer_name: order.customer_name,
          status: order.status,
          items_count: order.items_count,
          order_total: order.order_total,
          created_at: order.created_at
        }
      end,
      pagination: metadata
    }
  end
end
```

### Paginazione con Scope Personalizzati

```ruby
class User < ApplicationRecord
  include PanStuff::ActiveRecordPagination

  scope :active, -> { where(active: true) }
  scope :by_role, ->(role) { where(role: role) }
  scope :search, ->(term) { where('name ILIKE ? OR email ILIKE ?', "%#{term}%", "%#{term}%") }
  scope :recent, -> { order(created_at: :desc) }
end

# Nel controller
def index
  users = User.active
  users = users.by_role(params[:role]) if params[:role].present?
  users = users.search(params[:search]) if params[:search].present?
  users = users.recent

  paginated_users, metadata = users.paginate(
    current_page: params[:page]&.to_i || 1,
    items_per_page: params[:per_page]&.to_i || 25
  )

  render json: {
    data: UserSerializer.new(paginated_users).to_h[:data],
    pagination: metadata
  }
end
```

### Service Class per Paginazione Complessa

```ruby
class UserSearchService
  def initialize(params)
    @params = params
  end

  def call
    users = build_query
    paginate_results(users)
  end

  private

  def build_query
    users = User.includes(:company, :roles)

    # Filtri di ricerca
    users = users.where('name ILIKE ?', "%#{@params[:search]}%") if @params[:search].present?
    users = users.where(company_id: @params[:company_id]) if @params[:company_id].present?
    users = users.where(active: @params[:active]) if @params[:active].present?

    # Filtri per ruolo
    if @params[:role].present?
      users = users.joins(:roles).where(roles: { name: @params[:role] })
    end

    # Filtri per data
    if @params[:created_after].present?
      users = users.where('created_at >= ?', @params[:created_after])
    end

    # Ordinamento
    case @params[:sort]
    when 'name'
      users = users.order(:name)
    when 'email'
      users = users.order(:email)
    when 'created_at'
      users = users.order(:created_at)
    else
      users = users.order(:id)
    end

    users = users.order(:desc) if @params[:direction] == 'desc'

    users
  end

  def paginate_results(users)
    current_page = @params[:page]&.to_i || 1
    items_per_page = [@params[:per_page]&.to_i || 20, 100].min # Max 100 per pagina

    users.paginate(
      current_page: current_page,
      items_per_page: items_per_page
    )
  end
end

# Nel controller
def index
  users, metadata = UserSearchService.new(params).call

  render json: {
    data: UserSerializer.new(users).to_h[:data],
    pagination: metadata,
    applied_filters: extract_applied_filters
  }
end
```

## Integrazione con Frontend

### Risposta API Standardizzata

```ruby
class ApplicationController < ActionController::API
  protected

  def paginated_response(collection, serializer_class, additional_meta: {})
    {
      data: serializer_class.new(collection).to_h[:data],
      pagination: additional_meta[:pagination] || {},
      meta: additional_meta.except(:pagination)
    }
  end
end

# Utilizzo
def index
  users, pagination_metadata = User.paginate(
    current_page: params[:page]&.to_i || 1,
    items_per_page: params[:per_page]&.to_i || 20
  )

  render json: paginated_response(
    users,
    UserSerializer,
    additional_meta: {
      pagination: pagination_metadata,
      total_active_users: User.active.count,
      filters_applied: params.slice(:search, :role, :active).compact
    }
  )
end
```

### JavaScript Frontend Integration

```javascript
class PaginationManager {
  constructor(apiEndpoint, containerId) {
    this.apiEndpoint = apiEndpoint;
    this.container = document.getElementById(containerId);
    this.currentPage = 1;
    this.itemsPerPage = 20;
  }

  async loadPage(page = 1, filters = {}) {
    const params = new URLSearchParams({
      page: page,
      per_page: this.itemsPerPage,
      ...filters,
    });

    try {
      const response = await fetch(`${this.apiEndpoint}?${params}`);
      const data = await response.json();

      this.renderData(data.data);
      this.renderPagination(data.pagination);
      this.currentPage = page;
    } catch (error) {
      console.error("Errore nel caricamento dei dati:", error);
    }
  }

  renderPagination(pagination) {
    const { current_page, total_pages, total_count, items_per_page } =
      pagination;

    let paginationHtml = `
      <div class="pagination-info">
        Mostrando ${(current_page - 1) * items_per_page + 1}-${Math.min(
      current_page * items_per_page,
      total_count
    )} 
        di ${total_count} risultati
      </div>
      <div class="pagination-controls">
    `;

    // Pulsante Previous
    if (current_page > 1) {
      paginationHtml += `<button onclick="pagination.loadPage(${
        current_page - 1
      })">Precedente</button>`;
    }

    // Numeri di pagina
    const startPage = Math.max(1, current_page - 2);
    const endPage = Math.min(total_pages, current_page + 2);

    for (let i = startPage; i <= endPage; i++) {
      const activeClass = i === current_page ? "active" : "";
      paginationHtml += `<button class="${activeClass}" onclick="pagination.loadPage(${i})">${i}</button>`;
    }

    // Pulsante Next
    if (current_page < total_pages) {
      paginationHtml += `<button onclick="pagination.loadPage(${
        current_page + 1
      })">Successivo</button>`;
    }

    paginationHtml += "</div>";

    document.getElementById("pagination").innerHTML = paginationHtml;
  }
}

// Inizializzazione
const pagination = new PaginationManager("/api/users", "users-container");
pagination.loadPage(1);
```

## Performance e Best Practices

### Ottimizzazioni per Performance

```ruby
# 1. Usa includes per evitare N+1 queries
users, metadata = User.includes(:company, :roles)
                      .paginate(current_page: 1, items_per_page: 20)

# 2. Usa select per limitare i campi
users, metadata = User.select(:id, :name, :email, :created_at)
                      .paginate(current_page: 1, items_per_page: 20)

# 3. Aggiungi indici per colonne usate in WHERE e ORDER BY
# In migration:
# add_index :users, :created_at
# add_index :users, [:active, :created_at]

# 4. Limita il numero massimo di elementi per pagina
def safe_items_per_page
  [params[:per_page]&.to_i || 20, 100].min
end
```

### Validazione dei Parametri

```ruby
class UsersController < ApplicationController
  before_action :validate_pagination_params, only: [:index]

  private

  def validate_pagination_params
    @current_page = [params[:page]&.to_i || 1, 1].max
    @items_per_page = [[params[:per_page]&.to_i || 20, 1].max, 100].min
  end

  def index
    users, metadata = User.paginate(
      current_page: @current_page,
      items_per_page: @items_per_page
    )

    render json: {
      data: UserSerializer.new(users).to_h[:data],
      pagination: metadata
    }
  end
end
```

## Limitazioni e Considerazioni

### Limitazioni del Modulo

1. **OFFSET Performance**: Per dataset molto grandi, OFFSET può essere lento
2. **Conteggio Totale**: Il `COUNT(*)` può essere costoso su tabelle grandi
3. **Consistenza**: I dati possono cambiare tra le pagine

### Alternative per Dataset Grandi

```ruby
# Per dataset molto grandi, considera cursor-based pagination
class User < ApplicationRecord
  scope :after_id, ->(id) { where('id > ?', id) }
end

# Implementazione cursor-based
def index
  last_id = params[:after_id]&.to_i || 0
  limit = params[:limit]&.to_i || 20

  users = User.after_id(last_id).limit(limit + 1) # +1 per sapere se ci sono altre pagine

  has_more = users.count > limit
  users = users.limit(limit) if has_more

  render json: {
    data: UserSerializer.new(users).to_h[:data],
    pagination: {
      has_more: has_more,
      next_cursor: has_more ? users.last.id : nil
    }
  }
end
```

## Troubleshooting

### Performance Lente

- Aggiungi indici appropriati per le colonne usate in filtri e ordinamento
- Usa `includes` per prevenire N+1 queries
- Considera cursor-based pagination per dataset molto grandi

### Conteggi Incorretti

- Verifica che non ci siano filtri che influenzano il conteggio
- Controlla che le associazioni siano caricate correttamente

### Pagine Vuote

- Valida che `current_page` sia >= 1
- Controlla che `items_per_page` sia > 0
- Verifica che ci siano effettivamente dati da mostrare
