# SmartHashSerializer

Lo `SmartHashSerializer` estende l'`HashSerializer` aggiungendo la capacità di gestire automaticamente tipi di dati speciali come oggetti `Money` all'interno degli hash.

## Panoramica

Lo SmartHashSerializer è utile quando:

- Hai hash che contengono oggetti `Money`
- Vuoi serializzazione automatica di tipi speciali
- Hai strutture dati miste con oggetti complessi
- Vuoi mantenere la performance dell'HashSerializer con funzionalità aggiuntive

## Differenze con HashSerializer

Lo SmartHashSerializer preprocessa automaticamente i dati prima della serializzazione, convertendo:

- Oggetti `Money` in hash strutturati
- Array contenenti oggetti speciali
- Hash annidati con oggetti speciali

## Utilizzo Base

```ruby
# Hash con oggetto Money
data = {
  product_id: 1,
  name: "Laptop",
  price: Money.new(99999, "EUR"), # 999.99 EUR
  discount: Money.new(5000, "EUR") # 50.00 EUR
}

serializer = PanStuff::Serializer::SmartHashSerializer.new(data)
serializer.to_h
# => {
#   data: {
#     productId: 1,
#     name: "Laptop",
#     price: {
#       cents: 99999,
#       amount: 999.99,
#       currency: "EUR",
#       formattedText: "€999.99",
#       symbol: "€"
#     },
#     discount: {
#       cents: 5000,
#       amount: 50.0,
#       currency: "EUR",
#       formattedText: "€50.00",
#       symbol: "€"
#     }
#   }
# }
```

## Gestione di Array con Oggetti Money

```ruby
products = [
  {
    id: 1,
    name: "Laptop",
    price: Money.new(99999, "EUR")
  },
  {
    id: 2,
    name: "Mouse",
    price: Money.new(2999, "EUR")
  }
]

serializer = SmartHashSerializer.new(products)
serializer.to_h
# => {
#   data: [
#     {
#       id: 1,
#       name: "Laptop",
#       price: {
#         cents: 99999,
#         amount: 999.99,
#         currency: "EUR",
#         formattedText: "€999.99",
#         symbol: "€"
#       }
#     },
#     {
#       id: 2,
#       name: "Mouse",
#       price: {
#         cents: 2999,
#         amount: 29.99,
#         currency: "EUR",
#         formattedText: "€29.99",
#         symbol: "€"
#       }
#     }
#   ]
# }
```

## Strutture Annidate Complesse

```ruby
order_data = {
  order_id: "ORD-123",
  customer: {
    id: 1,
    name: "John Doe"
  },
  items: [
    {
      product_id: 1,
      quantity: 2,
      unit_price: Money.new(4999, "EUR"),
      total: Money.new(9998, "EUR")
    },
    {
      product_id: 2,
      quantity: 1,
      unit_price: Money.new(1999, "EUR"),
      total: Money.new(1999, "EUR")
    }
  ],
  subtotal: Money.new(11997, "EUR"),
  tax: Money.new(2399, "EUR"),
  total: Money.new(14396, "EUR")
}

serializer = SmartHashSerializer.new(order_data)
# Tutti gli oggetti Money vengono automaticamente serializzati
```

## Inizializzazione

L'inizializzazione è identica all'HashSerializer:

```ruby
# Hash con oggetti Money
SmartHashSerializer.new(data)

# Con metadati
SmartHashSerializer.new(data, meta: { currency: "EUR" })

# Con messaggio
SmartHashSerializer.new(data, message: "Prezzi aggiornati")

# Senza root
SmartHashSerializer.new(data, root: false)
```

## Esempi Pratici

### E-commerce: Prodotti con Prezzi

```ruby
class ProductService
  def get_products_with_prices
    Product.includes(:category).map do |product|
      {
        id: product.id,
        name: product.name,
        description: product.description,
        category: product.category.name,
        price: product.price, # Money object
        sale_price: product.sale_price, # Money object o nil
        created_at: product.created_at
      }
    end
  end
end

# Nel controller
def index
  products_data = ProductService.new.get_products_with_prices
  render json: SmartHashSerializer.new(
    products_data,
    meta: { total_count: Product.count }
  )
end
```

### Report Finanziari

```ruby
class FinancialReportService
  def monthly_report(month)
    {
      period: "#{month}/#{Date.current.year}",
      revenue: calculate_revenue(month),
      expenses: calculate_expenses(month),
      profit: calculate_profit(month),
      breakdown: {
        sales: sales_breakdown(month),
        costs: costs_breakdown(month)
      }
    }
  end

  private

  def calculate_revenue(month)
    Order.where(created_at: month_range(month))
         .sum(:total) # Restituisce Money object
  end

  def sales_breakdown(month)
    Category.all.map do |category|
      {
        category_name: category.name,
        total_sales: category.products
                            .joins(:orders)
                            .where(orders: { created_at: month_range(month) })
                            .sum(:total) # Money object
      }
    end
  end
end

# Utilizzo
report_data = FinancialReportService.new.monthly_report(Date.current.month)
render json: SmartHashSerializer.new(report_data, message: "Report generato")
```

### Carrello della Spesa

```ruby
class CartSerializer
  def self.serialize(cart)
    cart_data = {
      cart_id: cart.id,
      user_id: cart.user_id,
      items: cart.items.map do |item|
        {
          product_id: item.product_id,
          product_name: item.product.name,
          quantity: item.quantity,
          unit_price: item.product.price, # Money object
          line_total: item.product.price * item.quantity # Money object
        }
      end,
      subtotal: cart.subtotal, # Money object
      tax: cart.tax_amount, # Money object
      shipping: cart.shipping_cost, # Money object
      total: cart.total # Money object
    }

    SmartHashSerializer.new(cart_data)
  end
end
```

## Confronto con Altri Serializzatori

| Caratteristica    | SmartHashSerializer | HashSerializer | ObjectSerializer  |
| ----------------- | ------------------- | -------------- | ----------------- |
| **Oggetti Money** | Automatico          | No             | Manuale           |
| **Performance**   | Buona               | Migliore       | Più lenta         |
| **Preprocessing** | Sì                  | No             | No                |
| **Flessibilità**  | Media               | Bassa          | Alta              |
| **Uso Ideale**    | Hash con Money      | Hash semplici  | Oggetti complessi |

## Tipi Supportati

Attualmente SmartHashSerializer gestisce automaticamente:

- **Money**: Convertito usando MoneySerializer
- **Hash**: Processato ricorsivamente
- **Array**: Processato ricorsivamente
- **Altri tipi**: Passati invariati

## Best Practices

1. **Usa per Dati Finanziari**: Ideale quando lavori con prezzi, importi, valute
2. **Performance**: Più lento dell'HashSerializer ma più veloce dell'ObjectSerializer
3. **Consistenza**: Assicura serializzazione consistente degli oggetti Money
4. **Validazione**: Verifica che gli oggetti Money siano validi prima della serializzazione

## Esempi Avanzati

### Multi-Currency Support

```ruby
products_data = [
  {
    id: 1,
    name: "Product US",
    price_usd: Money.new(9999, "USD"),
    price_eur: Money.new(8999, "EUR")
  },
  {
    id: 2,
    name: "Product EU",
    price_usd: Money.new(1999, "USD"),
    price_eur: Money.new(1799, "EUR")
  }
]

serializer = SmartHashSerializer.new(
  products_data,
  meta: { supported_currencies: ["USD", "EUR"] }
)
```

### Integrazione con Sistemi di Pagamento

```ruby
payment_data = {
  payment_id: "pay_123",
  amount: Money.new(5000, "EUR"),
  fee: Money.new(150, "EUR"),
  net_amount: Money.new(4850, "EUR"),
  refunds: [
    {
      refund_id: "ref_1",
      amount: Money.new(1000, "EUR"),
      reason: "Customer request"
    }
  ],
  remaining_amount: Money.new(3850, "EUR")
}

serializer = SmartHashSerializer.new(payment_data)
```

## Estensibilità

Per aggiungere supporto per altri tipi, puoi estendere la classe:

```ruby
class CustomSmartHashSerializer < SmartHashSerializer
  private

  def check_type(stuff)
    case stuff
    when Date
      stuff.iso8601
    when DateTime, Time
      stuff.iso8601
    when BigDecimal
      stuff.to_f
    else
      super(stuff)
    end
  end
end
```

## Troubleshooting

### Oggetti Money Non Serializzati

- Verifica che la gem `money` sia installata
- Controlla che gli oggetti siano istanze valide di `Money`

### Performance Issues

- Per hash molto grandi con molti oggetti Money, considera la cache
- Usa HashSerializer se non hai oggetti Money

### Errori di Conversione

- Assicurati che gli oggetti Money abbiano valute valide
- Verifica che i valori numerici siano corretti
