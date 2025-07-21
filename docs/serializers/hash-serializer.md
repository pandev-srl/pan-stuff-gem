# HashSerializer

L'`HashSerializer` è un serializzatore semplice e veloce per convertire hash Ruby in formato JSON con trasformazione automatica delle chiavi.

## Panoramica

L'HashSerializer è ideale quando:

- Hai già i dati in formato hash
- Non hai bisogno di logica di serializzazione complessa
- Vuoi una soluzione performante per dati semplici
- Devi trasformare le chiavi (camelCase, underscore)

## Utilizzo Base

```ruby
# Hash semplice
data = { user_id: 1, first_name: "John", last_name: "Doe" }
serializer = PanStuff::Serializer::HashSerializer.new(data)
serializer.to_h
# => { data: { userId: 1, firstName: "John", lastName: "Doe" } }
```

## Inizializzazione

```ruby
# Hash singolo
HashSerializer.new(hash)

# Con metadati
HashSerializer.new(hash, meta: { total_count: 100 })

# Con messaggio
HashSerializer.new(hash, message: "Operazione completata")

# Con context (per compatibilità)
HashSerializer.new(hash, context: { current_user: user })

# Senza root
HashSerializer.new(hash, root: false)

# Esempio completo
HashSerializer.new(
  data,
  meta: { page: 1, per_page: 10 },
  message: "Dati recuperati con successo",
  root: true
)
```

## Gestione delle Collezioni

```ruby
# Array di hash
users_data = [
  { id: 1, name: "John", email: "john@example.com" },
  { id: 2, name: "Jane", email: "jane@example.com" }
]

serializer = HashSerializer.new(users_data)
serializer.to_h
# => {
#   data: [
#     { id: 1, name: "John", email: "john@example.com" },
#     { id: 2, name: "Jane", email: "jane@example.com" }
#   ]
# }
```

## Trasformazione delle Chiavi

L'HashSerializer trasforma automaticamente tutte le chiavi dell'hash, incluse quelle annidate:

```ruby
data = {
  user_id: 1,
  user_profile: {
    first_name: "John",
    last_name: "Doe",
    contact_info: {
      phone_number: "+1234567890",
      email_address: "john@example.com"
    }
  }
}

serializer = HashSerializer.new(data)
serializer.to_h
# => {
#   data: {
#     userId: 1,
#     userProfile: {
#       firstName: "John",
#       lastName: "Doe",
#       contactInfo: {
#         phoneNumber: "+1234567890",
#         emailAddress: "john@example.com"
#       }
#     }
#   }
# }
```

## Struttura della Risposta

### Con Root (default)

```ruby
{
  "data": {
    "userId": 1,
    "firstName": "John"
  },
  "meta": {
    "totalCount": 100
  },
  "message": "Operazione completata"
}
```

### Senza Root

```ruby
{
  "userId": 1,
  "firstName": "John"
}
```

## Esempi Pratici

### Serializzazione di Dati da Database

```ruby
# Nel controller
def index
  users_data = User.select(:id, :name, :email, :created_at)
                  .limit(10)
                  .map(&:attributes)

  render json: HashSerializer.new(
    users_data,
    meta: { total_count: User.count },
    message: "Utenti recuperati con successo"
  )
end
```

### Serializzazione di Risultati di Query Complesse

```ruby
# Query con join e aggregazioni
stats_data = User.joins(:orders)
                 .group(:id)
                 .select('users.id, users.name, COUNT(orders.id) as order_count, SUM(orders.total) as total_spent')
                 .map do |user|
  {
    user_id: user.id,
    user_name: user.name,
    order_count: user.order_count,
    total_spent: user.total_spent.to_f
  }
end

serializer = HashSerializer.new(stats_data)
```

### Combinazione con Altri Serializzatori

```ruby
# Nel service
class UserStatsService
  def call
    base_data = {
      total_users: User.count,
      active_users: User.active.count,
      new_users_today: User.where(created_at: Date.current.all_day).count
    }

    detailed_users = User.recent.limit(5).map do |user|
      UserSerializer.new(user, root: false).to_h
    end

    {
      stats: base_data,
      recent_users: detailed_users
    }
  end
end

# Nel controller
def dashboard
  data = UserStatsService.new.call
  render json: HashSerializer.new(data, message: "Dashboard caricata")
end
```

## Confronto con ObjectSerializer

| Caratteristica              | HashSerializer             | ObjectSerializer |
| --------------------------- | -------------------------- | ---------------- |
| **Input**                   | Hash/Array di Hash         | Oggetti Ruby     |
| **Performance**             | Più veloce                 | Più lento        |
| **Flessibilità**            | Limitata                   | Alta             |
| **Logica Custom**           | No                         | Sì               |
| **Attributi Condizionali**  | No                         | Sì               |
| **Serializzatori Annidati** | No                         | Sì               |
| **Uso Ideale**              | Dati semplici, performance | Logica complessa |

## Best Practices

1. **Usa per Dati Semplici**: Ideale per hash già pronti o risultati di query semplici
2. **Performance**: Preferisci HashSerializer quando non hai bisogno di logica complessa
3. **Preparazione Dati**: Prepara i dati nel formato corretto prima della serializzazione
4. **Combinazione**: Combina con ObjectSerializer per casi d'uso misti
5. **Validazione**: Assicurati che l'input sia un hash valido

## Esempi Avanzati

### Serializzazione di Dati API Esterni

```ruby
# Dati da API esterna
external_data = {
  user_info: {
    external_id: "ext_123",
    display_name: "John Doe",
    profile_image: "https://example.com/avatar.jpg"
  },
  permissions: ["read", "write"],
  last_login: "2023-01-01T10:00:00Z"
}

serializer = HashSerializer.new(
  external_data,
  meta: { source: "external_api", cached: true }
)
```

### Aggregazione di Dati da Fonti Multiple

```ruby
class DashboardDataService
  def call
    {
      user_stats: user_statistics,
      order_stats: order_statistics,
      revenue_stats: revenue_statistics
    }
  end

  private

  def user_statistics
    {
      total_count: User.count,
      active_count: User.active.count,
      growth_rate: calculate_growth_rate
    }
  end

  def order_statistics
    {
      today_orders: Order.today.count,
      pending_orders: Order.pending.count,
      completed_orders: Order.completed.count
    }
  end

  def revenue_statistics
    {
      today_revenue: Order.today.sum(:total),
      monthly_revenue: Order.current_month.sum(:total),
      average_order_value: Order.average(:total)
    }
  end
end

# Utilizzo
data = DashboardDataService.new.call
render json: HashSerializer.new(data, message: "Dashboard aggiornata")
```

## Troubleshooting

### Hash Non Valido

Se ricevi errori di serializzazione:

- Verifica che l'input sia un hash o array di hash
- Controlla che non ci siano valori non serializzabili (oggetti complessi)

### Chiavi Non Trasformate

Se le chiavi non vengono trasformate:

- Assicurati che siano simboli o stringhe
- Verifica la configurazione di `transform_method` se personalizzata

### Performance Issues

- HashSerializer è già ottimizzato per performance
- Per hash molto grandi, considera la paginazione
- Evita hash con strutture troppo annidate
