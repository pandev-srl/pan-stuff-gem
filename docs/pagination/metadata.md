# Pagination Metadata

La classe `Metadata` e il `MetadataSerializer` forniscono una struttura standardizzata per gestire e serializzare i metadati di paginazione in PanStuff.

## Panoramica

Il sistema di metadati di paginazione include:

- **Metadata**: Classe modello per contenere informazioni di paginazione
- **MetadataSerializer**: Serializzatore per convertire i metadati in formato JSON
- Integrazione con ActiveRecordPagination
- Struttura consistente per tutte le risposte paginate

## Metadata Class

La classe `Metadata` è un modello ActiveModel che contiene le informazioni essenziali per la paginazione:

```ruby
metadata = PanStuff::Pagination::Metadata.new(
  total_count: 150,
  total_pages: 15,
  current_page: 1,
  items_per_page: 10
)
```

### Attributi Disponibili

| Attributo        | Tipo    | Descrizione             |
| ---------------- | ------- | ----------------------- |
| `total_count`    | Integer | Numero totale di record |
| `total_pages`    | Integer | Numero totale di pagine |
| `current_page`   | Integer | Pagina corrente         |
| `items_per_page` | Integer | Elementi per pagina     |

## MetadataSerializer

Il `MetadataSerializer` estende `ObjectSerializer` per fornire serializzazione standardizzata:

```ruby
metadata = PanStuff::Pagination::Metadata.new(
  total_count: 150,
  total_pages: 15,
  current_page: 1,
  items_per_page: 10
)

serializer = PanStuff::Pagination::MetadataSerializer.new(metadata)
serializer.to_h
# => {
#   data: {
#     totalCount: 150,
#     totalPages: 15,
#     currentPage: 1,
#     itemsPerPage: 10
#   }
# }
```

## Utilizzo Base

### Creazione Manuale

```ruby
# Creazione diretta
metadata = PanStuff::Pagination::Metadata.new(
  total_count: User.count,
  total_pages: (User.count.to_f / 20).ceil,
  current_page: 1,
  items_per_page: 20
)

# Serializzazione
serializer = PanStuff::Pagination::MetadataSerializer.new(metadata)
```

### Con ActiveRecordPagination

```ruby
# ActiveRecordPagination restituisce già un hash compatibile
users, metadata_hash = User.paginate(current_page: 1, items_per_page: 20)

# Conversione in oggetto Metadata
metadata = PanStuff::Pagination::Metadata.new(metadata_hash)
serializer = PanStuff::Pagination::MetadataSerializer.new(metadata)
```

## Esempi Pratici

### Controller con Metadata Esplicita

```ruby
class UsersController < ApplicationController
  def index
    # Paginazione
    users, metadata_hash = User.paginate(
      current_page: params[:page]&.to_i || 1,
      items_per_page: params[:per_page]&.to_i || 20
    )

    # Creazione oggetto Metadata
    metadata = PanStuff::Pagination::Metadata.new(metadata_hash)

    render json: {
      data: UserSerializer.new(users).to_h[:data],
      pagination: PanStuff::Pagination::MetadataSerializer.new(metadata, root: false).to_h
    }
  end
end
```

### Service Class per Paginazione

```ruby
class PaginationService
  def self.paginate_collection(collection, page: 1, per_page: 20)
    # Calcoli di paginazione
    total_count = collection.count
    total_pages = (total_count.to_f / per_page).ceil
    offset = (page - 1) * per_page

    # Collezione paginata
    paginated_collection = collection.limit(per_page).offset(offset)

    # Metadati
    metadata = PanStuff::Pagination::Metadata.new(
      total_count: total_count,
      total_pages: total_pages,
      current_page: page,
      items_per_page: per_page
    )

    [paginated_collection, metadata]
  end
end

# Utilizzo
class ProductsController < ApplicationController
  def index
    products = Product.includes(:category)
    products = apply_filters(products)

    paginated_products, metadata = PaginationService.paginate_collection(
      products,
      page: params[:page]&.to_i || 1,
      per_page: params[:per_page]&.to_i || 12
    )

    render json: {
      data: ProductSerializer.new(paginated_products).to_h[:data],
      pagination: PanStuff::Pagination::MetadataSerializer.new(metadata, root: false).to_h
    }
  end
end
```

### Metadata Estesa

```ruby
class ExtendedMetadata < PanStuff::Pagination::Metadata
  attribute :has_previous_page, :boolean
  attribute :has_next_page, :boolean
  attribute :previous_page, :integer
  attribute :next_page, :integer
  attribute :first_item_number, :integer
  attribute :last_item_number, :integer

  def initialize(attributes = {})
    super(attributes)
    calculate_derived_attributes
  end

  private

  def calculate_derived_attributes
    self.has_previous_page = current_page > 1
    self.has_next_page = current_page < total_pages
    self.previous_page = has_previous_page ? current_page - 1 : nil
    self.next_page = has_next_page ? current_page + 1 : nil

    if total_count > 0
      self.first_item_number = (current_page - 1) * items_per_page + 1
      self.last_item_number = [current_page * items_per_page, total_count].min
    else
      self.first_item_number = 0
      self.last_item_number = 0
    end
  end
end

class ExtendedMetadataSerializer < PanStuff::Pagination::MetadataSerializer
  attribute :has_previous_page
  attribute :has_next_page
  attribute :previous_page
  attribute :next_page
  attribute :first_item_number
  attribute :last_item_number
end

# Utilizzo
def index
  users, metadata_hash = User.paginate(current_page: 2, items_per_page: 10)

  extended_metadata = ExtendedMetadata.new(metadata_hash)
  serializer = ExtendedMetadataSerializer.new(extended_metadata, root: false)

  # Risultato:
  # {
  #   totalCount: 150,
  #   totalPages: 15,
  #   currentPage: 2,
  #   itemsPerPage: 10,
  #   hasPreviousPage: true,
  #   hasNextPage: true,
  #   previousPage: 1,
  #   nextPage: 3,
  #   firstItemNumber: 11,
  #   lastItemNumber: 20
  # }
end
```

## Integrazione con ResourcesController

```ruby
class UsersController < ApplicationController
  include PanStuff::ResourcesController

  private

  def resource_collection_resolver
    users = User.includes(:company)
    users = apply_filters(users)

    # Paginazione con ActiveRecordPagination
    paginated_users, metadata_hash = users.paginate(
      current_page: params[:page]&.to_i || 1,
      items_per_page: params[:per_page]&.to_i || 20
    )

    # Aggiungi metadati serializzati ai meta del controller
    metadata = PanStuff::Pagination::Metadata.new(metadata_hash)
    serialized_metadata = PanStuff::Pagination::MetadataSerializer.new(metadata, root: false).to_h
    add_meta(:pagination, serialized_metadata)

    paginated_users
  end
end
```

## Esempi Avanzati

### Metadata con Informazioni Aggiuntive

```ruby
class SearchMetadata < PanStuff::Pagination::Metadata
  attribute :search_term, :string
  attribute :filters_applied, :hash
  attribute :sort_by, :string
  attribute :sort_direction, :string
  attribute :search_duration_ms, :integer

  def initialize(attributes = {})
    super(attributes)
    self.filters_applied ||= {}
  end
end

class SearchMetadataSerializer < PanStuff::Pagination::MetadataSerializer
  attribute :search_term
  attribute :filters_applied
  attribute :sort_by
  attribute :sort_direction
  attribute :search_duration_ms
end

# Nel controller
def search
  start_time = Time.current

  users = User.includes(:company)
  users = users.where('name ILIKE ?', "%#{params[:search]}%") if params[:search].present?
  users = users.where(active: params[:active]) if params[:active].present?
  users = users.order("#{params[:sort] || 'created_at'} #{params[:direction] || 'desc'}")

  paginated_users, base_metadata = users.paginate(
    current_page: params[:page]&.to_i || 1,
    items_per_page: params[:per_page]&.to_i || 20
  )

  search_metadata = SearchMetadata.new(
    base_metadata.merge(
      search_term: params[:search],
      filters_applied: params.slice(:active, :company_id).compact,
      sort_by: params[:sort] || 'created_at',
      sort_direction: params[:direction] || 'desc',
      search_duration_ms: ((Time.current - start_time) * 1000).round
    )
  )

  render json: {
    data: UserSerializer.new(paginated_users).to_h[:data],
    pagination: SearchMetadataSerializer.new(search_metadata, root: false).to_h
  }
end
```

### Metadata per API Versionate

```ruby
module Api
  module V1
    class PaginationMetadataSerializer < PanStuff::Pagination::MetadataSerializer
      # API v1 usa nomi diversi
      attribute :total, method: :total_count
      attribute :pages, method: :total_pages
      attribute :page, method: :current_page
      attribute :per_page, method: :items_per_page
    end
  end

  module V2
    class PaginationMetadataSerializer < PanStuff::Pagination::MetadataSerializer
      # API v2 usa la struttura standard
      # Eredita tutti gli attributi dal serializzatore base

      # Aggiunge informazioni aggiuntive
      attribute :api_version, method: :get_api_version

      private

      def get_api_version(metadata)
        "v2"
      end
    end
  end
end
```

### Caching dei Metadati

```ruby
class CachedPaginationService
  def self.paginate_with_cache(model_class, cache_key, page: 1, per_page: 20)
    # Cache del conteggio totale per 5 minuti
    total_count = Rails.cache.fetch("#{cache_key}_count", expires_in: 5.minutes) do
      model_class.count
    end

    total_pages = (total_count.to_f / per_page).ceil
    offset = (page - 1) * per_page

    # Collezione paginata
    collection = model_class.limit(per_page).offset(offset)

    # Metadati
    metadata = PanStuff::Pagination::Metadata.new(
      total_count: total_count,
      total_pages: total_pages,
      current_page: page,
      items_per_page: per_page
    )

    [collection, metadata]
  end
end

# Utilizzo
def index
  users, metadata = CachedPaginationService.paginate_with_cache(
    User,
    "users_pagination",
    page: params[:page]&.to_i || 1,
    per_page: params[:per_page]&.to_i || 20
  )

  render json: {
    data: UserSerializer.new(users).to_h[:data],
    pagination: PanStuff::Pagination::MetadataSerializer.new(metadata, root: false).to_h
  }
end
```

## Best Practices

1. **Consistenza**: Usa sempre la stessa struttura di metadati in tutta l'applicazione
2. **Validazione**: Valida i parametri di paginazione prima di creare i metadati
3. **Performance**: Considera il caching per conteggi costosi
4. **Estensibilità**: Estendi le classi base per aggiungere metadati specifici
5. **Documentazione**: Documenta chiaramente la struttura dei metadati per i client API

## Validazione dei Metadati

```ruby
class ValidatedMetadata < PanStuff::Pagination::Metadata
  validates :total_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_pages, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :current_page, presence: true, numericality: { greater_than: 0 }
  validates :items_per_page, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }

  validate :current_page_within_bounds

  private

  def current_page_within_bounds
    return unless current_page && total_pages

    if current_page > total_pages && total_pages > 0
      errors.add(:current_page, "non può essere maggiore del numero totale di pagine")
    end
  end
end
```

## Troubleshooting

### Metadati Incorretti

- Verifica che i calcoli di paginazione siano corretti
- Controlla che `total_count` rifletta i filtri applicati
- Assicurati che `items_per_page` sia > 0

### Serializzazione Non Corretta

- Verifica che tutti gli attributi siano definiti nel serializzatore
- Controlla la trasformazione delle chiavi (camelCase vs underscore)
- Assicurati di usare `root: false` quando appropriato

### Performance Issues

- Usa caching per conteggi costosi
- Considera l'uso di `count` invece di `size` per query complesse
- Evita di calcolare metadati non necessari
