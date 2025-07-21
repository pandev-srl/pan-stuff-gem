# ParamsHelpers

Il modulo `ParamsHelpers` fornisce metodi di utilità per gestire e processare i parametri delle richieste HTTP in modo standardizzato, con supporto per trasformazioni automatiche e parsing intelligente.

## Panoramica

ParamsHelpers offre:

- Accesso semplificato ai parametri di richiesta e query
- Trasformazione automatica delle chiavi (camelCase → underscore)
- Simbolizzazione delle chiavi per consistenza
- Parsing intelligente di valori speciali (null, undefined)
- Gestione ricorsiva di hash e array annidati

## Installazione

Includi il modulo nel tuo controller:

```ruby
class ApplicationController < ActionController::API
  include PanStuff::ParamsHelpers
end
```

## Metodi Disponibili

### `request_params`

Restituisce i parametri del corpo della richiesta (POST, PUT, PATCH) come hash con chiavi simbolizzate.

```ruby
# POST /users
# Body: { "user": { "firstName": "John", "lastName": "Doe" } }

def create
  params = request_params
  # => { user: { firstName: "John", lastName: "Doe" } }
end
```

### `query_params`

Restituisce i parametri della query string con trasformazioni automatiche:

- Trasforma le chiavi da camelCase a underscore
- Simbolizza tutte le chiavi
- Converte valori speciali ('null', 'undefined') in `nil`
- Gestisce strutture annidate ricorsivamente

```ruby
# GET /users?firstName=John&companyId=123&isActive=true&tags[]=ruby&tags[]=rails

def index
  params = query_params
  # => {
  #   first_name: "John",
  #   company_id: "123",
  #   is_active: "true",
  #   tags: ["ruby", "rails"]
  # }
end
```

## Esempi Pratici

### Controller Base con Filtri

```ruby
class UsersController < ApplicationController
  include PanStuff::ParamsHelpers

  def index
    # Usa query_params per filtri dalla URL
    filters = query_params

    users = User.all
    users = users.where(active: true) if filters[:is_active] == 'true'
    users = users.where('name ILIKE ?', "%#{filters[:search]}%") if filters[:search].present?
    users = users.where(company_id: filters[:company_id]) if filters[:company_id].present?

    render json: UserSerializer.new(users)
  end

  def create
    # Usa request_params per dati del corpo della richiesta
    user_data = request_params[:user]

    @user = User.new(user_data)
    if @user.save
      render json: UserSerializer.new(@user), status: :created
    else
      render json: { errors: @user.errors }, status: :unprocessable_entity
    end
  end
end
```

### Gestione di Parametri Complessi

```ruby
class ProductsController < ApplicationController
  include PanStuff::ParamsHelpers

  def search
    # Query: /products/search?filters[category]=electronics&filters[priceRange][min]=100&filters[priceRange][max]=500&sortBy=price&sortDirection=asc

    search_params = query_params
    # => {
    #   filters: {
    #     category: "electronics",
    #     price_range: {
    #       min: "100",
    #       max: "500"
    #     }
    #   },
    #   sort_by: "price",
    #   sort_direction: "asc"
    # }

    products = Product.includes(:category)

    # Applica filtri
    if search_params[:filters].present?
      filters = search_params[:filters]

      products = products.joins(:category).where(categories: { name: filters[:category] }) if filters[:category].present?

      if filters[:price_range].present?
        price_range = filters[:price_range]
        products = products.where('price >= ?', price_range[:min]) if price_range[:min].present?
        products = products.where('price <= ?', price_range[:max]) if price_range[:max].present?
      end
    end

    # Applica ordinamento
    if search_params[:sort_by].present?
      direction = search_params[:sort_direction] == 'desc' ? :desc : :asc
      products = products.order(search_params[:sort_by] => direction)
    end

    render json: ProductSerializer.new(products)
  end
end
```

### Integrazione con ResourcesController

```ruby
class UsersController < ApplicationController
  include PanStuff::ResourcesController
  include PanStuff::ParamsHelpers

  private

  def resource_collection_resolver
    users = User.includes(:company)

    # Usa query_params per filtri
    filters = query_params
    users = apply_filters(users, filters)

    users
  end

  def apply_filters(relation, filters)
    relation = relation.where(active: true) if filters[:is_active] == 'true'
    relation = relation.where('name ILIKE ?', "%#{filters[:search]}%") if filters[:search].present?
    relation = relation.where(company_id: filters[:company_id]) if filters[:company_id].present?

    # Filtri per data
    if filters[:created_after].present?
      relation = relation.where('created_at >= ?', Date.parse(filters[:created_after]))
    end

    relation
  end

  def resource_params
    # Usa request_params invece di params direttamente
    request_params.fetch(:user)
  end
end
```

## Esempi Avanzati

### Service Class per Parsing Parametri

```ruby
class ParameterParsingService
  include PanStuff::ParamsHelpers

  def initialize(request)
    @request = request
  end

  def parse_search_params
    params = query_params

    {
      search_term: params[:q] || params[:search],
      filters: extract_filters(params),
      sorting: extract_sorting(params),
      pagination: extract_pagination(params)
    }
  end

  def parse_bulk_operation_params
    params = request_params

    {
      operation: params[:operation],
      target_ids: Array(params[:target_ids]),
      options: params[:options] || {}
    }
  end

  private

  attr_reader :request

  def extract_filters(params)
    filter_keys = [:category, :status, :is_active, :company_id, :created_after, :created_before]
    params.slice(*filter_keys).compact
  end

  def extract_sorting(params)
    {
      sort_by: params[:sort_by] || params[:sort] || 'created_at',
      sort_direction: params[:sort_direction] || params[:direction] || 'desc'
    }
  end

  def extract_pagination(params)
    {
      page: [params[:page]&.to_i || 1, 1].max,
      per_page: [[params[:per_page]&.to_i || 20, 1].max, 100].min
    }
  end
end

# Nel controller
class UsersController < ApplicationController
  def index
    parser = ParameterParsingService.new(request)
    search_params = parser.parse_search_params

    users = UserSearchService.new(search_params).call
    render json: UserSerializer.new(users)
  end

  def bulk_update
    parser = ParameterParsingService.new(request)
    bulk_params = parser.parse_bulk_operation_params

    result = UserBulkOperationService.new(bulk_params).call
    render json: { success: result.success?, message: result.message }
  end
end
```

### Validazione e Sanitizzazione Parametri

```ruby
class ParameterValidator
  include PanStuff::ParamsHelpers
  include ActiveModel::Validations

  attr_accessor :search_term, :category, :price_min, :price_max, :sort_by, :sort_direction

  validates :search_term, length: { maximum: 100 }
  validates :category, inclusion: { in: %w[electronics clothing books] }, allow_blank: true
  validates :price_min, :price_max, numericality: { greater_than: 0 }, allow_blank: true
  validates :sort_by, inclusion: { in: %w[name price created_at] }, allow_blank: true
  validates :sort_direction, inclusion: { in: %w[asc desc] }, allow_blank: true

  def initialize(request)
    @request = request
    parse_and_assign_params
  end

  def valid_params
    return {} unless valid?

    {
      search_term: search_term,
      category: category,
      price_min: price_min&.to_f,
      price_max: price_max&.to_f,
      sort_by: sort_by || 'created_at',
      sort_direction: sort_direction || 'desc'
    }.compact
  end

  private

  attr_reader :request

  def parse_and_assign_params
    params = query_params

    self.search_term = params[:search]
    self.category = params[:category]
    self.price_min = params[:price_min]
    self.price_max = params[:price_max]
    self.sort_by = params[:sort_by]
    self.sort_direction = params[:sort_direction]
  end
end

# Nel controller
def search
  validator = ParameterValidator.new(request)

  unless validator.valid?
    render json: { errors: validator.errors }, status: :bad_request
    return
  end

  products = ProductSearchService.new(validator.valid_params).call
  render json: ProductSerializer.new(products)
end
```

### Gestione di File Upload

```ruby
class FileUploadController < ApplicationController
  include PanStuff::ParamsHelpers

  def upload
    upload_params = request_params

    # Gestione file
    file = upload_params[:file]
    unless file.present?
      render json: { error: 'File richiesto' }, status: :bad_request
      return
    end

    # Metadati del file
    metadata = {
      original_filename: file.original_filename,
      content_type: file.content_type,
      size: file.size,
      description: upload_params[:description],
      tags: upload_params[:tags] || []
    }

    # Salva file
    uploaded_file = FileUploadService.new(file, metadata).call

    if uploaded_file.persisted?
      render json: FileSerializer.new(uploaded_file), status: :created
    else
      render json: { errors: uploaded_file.errors }, status: :unprocessable_entity
    end
  end
end
```

## Trasformazioni Automatiche

### Conversione delle Chiavi

```ruby
# Query: ?firstName=John&lastName=Doe&companyId=123
query_params
# => { first_name: "John", last_name: "Doe", company_id: "123" }

# Body: { "userProfile": { "firstName": "John", "contactInfo": { "phoneNumber": "+123" } } }
request_params
# => { userProfile: { firstName: "John", contactInfo: { phoneNumber: "+123" } } }
```

### Gestione Valori Speciali

```ruby
# Query: ?name=John&age=null&active=undefined&tags[]=ruby&tags[]=null
query_params
# => { name: "John", age: nil, active: nil, tags: ["ruby", nil] }
```

### Strutture Annidate

```ruby
# Query: ?filters[user][name]=John&filters[user][active]=true&filters[date][from]=2023-01-01
query_params
# => {
#   filters: {
#     user: { name: "John", active: "true" },
#     date: { from: "2023-01-01" }
#   }
# }
```

## Best Practices

1. **Usa query_params per Filtri**: Ideale per parametri di ricerca e filtri dalla URL
2. **Usa request_params per Dati**: Perfetto per dati del corpo della richiesta (POST, PUT)
3. **Valida Sempre**: Implementa validazione per parametri critici
4. **Sanitizza Input**: Pulisci e valida i dati prima dell'uso
5. **Gestisci Errori**: Fornisci messaggi di errore chiari per parametri non validi

## Integrazione con Frontend

### JavaScript/TypeScript

```javascript
// Invio di parametri che verranno processati correttamente
const searchParams = new URLSearchParams({
  firstName: "John",
  companyId: "123",
  isActive: "true",
  "tags[]": ["ruby", "rails"],
});

fetch(`/api/users?${searchParams}`);
// Query risultante: ?firstName=John&companyId=123&isActive=true&tags[]=ruby&tags[]=rails
// Parametri ricevuti: { first_name: "John", company_id: "123", is_active: "true", tags: ["ruby", "rails"] }

// Invio di dati nel corpo della richiesta
const userData = {
  user: {
    firstName: "John",
    lastName: "Doe",
    contactInfo: {
      email: "john@example.com",
      phoneNumber: "+1234567890",
    },
  },
};

fetch("/api/users", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(userData),
});
// Parametri ricevuti: { user: { firstName: "John", lastName: "Doe", contactInfo: { email: "john@example.com", phoneNumber: "+1234567890" } } }
```

## Troubleshooting

### Parametri Non Trovati

- Verifica che i parametri siano inviati correttamente dal client
- Controlla che il Content-Type sia impostato per richieste POST/PUT
- Usa `request_params` per dati del corpo e `query_params` per query string

### Trasformazioni Inaspettate

- Le chiavi in `query_params` vengono trasformate da camelCase a underscore
- Le chiavi in `request_params` mantengono il formato originale
- I valori 'null' e 'undefined' vengono convertiti in `nil`

### Performance Issues

- Per parametri molto complessi, considera la validazione lazy
- Evita di chiamare `query_params` o `request_params` multiple volte
- Usa caching per parsing costosi

### Errori di Parsing

- Verifica che i parametri annidati siano formattati correttamente
- Controlla che gli array siano inviati con la sintassi corretta (`param[]=value`)
- Assicurati che i valori JSON siano validi per richieste con Content-Type application/json
