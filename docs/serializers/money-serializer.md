# MoneySerializer

Il `MoneySerializer` è un serializzatore specializzato per oggetti `Money` della gem Ruby Money, fornendo una rappresentazione JSON completa e standardizzata degli importi monetari.

## Panoramica

Il MoneySerializer converte oggetti `Money` in hash strutturati contenenti:

- **cents**: Valore in centesimi (intero)
- **amount**: Valore decimale (float)
- **currency**: Codice ISO della valuta
- **formatted_text**: Testo formattato con simbolo
- **symbol**: Simbolo della valuta

## Utilizzo Base

```ruby
require 'money'

# Crea un oggetto Money
price = Money.new(99999, "EUR") # 999.99 EUR

# Serializza
serializer = PanStuff::Serializer::MoneySerializer.new(price)
serializer.to_h
# => {
#   data: {
#     cents: 99999,
#     amount: 999.99,
#     currency: "EUR",
#     formattedText: "€ 999.99",
#     symbol: "€"
#   }
# }
```

## Struttura della Risposta

### Con Root (default)

```json
{
  "data": {
    "cents": 99999,
    "amount": 999.99,
    "currency": "EUR",
    "formattedText": "€ 999.99",
    "symbol": "€"
  }
}
```

### Senza Root

```json
{
  "cents": 99999,
  "amount": 999.99,
  "currency": "EUR",
  "formattedText": "€ 999.99",
  "symbol": "€"
}
```

## Esempi con Diverse Valute

### Euro (EUR)

```ruby
price_eur = Money.new(12345, "EUR") # 123.45 EUR
MoneySerializer.new(price_eur).to_h
# => {
#   data: {
#     cents: 12345,
#     amount: 123.45,
#     currency: "EUR",
#     formattedText: "€ 123.45",
#     symbol: "€"
#   }
# }
```

### Dollaro Americano (USD)

```ruby
price_usd = Money.new(54321, "USD") # 543.21 USD
MoneySerializer.new(price_usd).to_h
# => {
#   data: {
#     cents: 54321,
#     amount: 543.21,
#     currency: "USD",
#     formattedText: "$ 543.21",
#     symbol: "$"
#   }
# }
```

### Yen Giapponese (JPY)

```ruby
price_jpy = Money.new(1000, "JPY") # 1000 JPY (no decimali)
MoneySerializer.new(price_jpy).to_h
# => {
#   data: {
#     cents: 1000,
#     amount: 1000.0,
#     currency: "JPY",
#     formattedText: "¥ 1,000",
#     symbol: "¥"
#   }
# }
```

## Utilizzo in Serializzatori Annidati

### In ObjectSerializer

```ruby
class ProductSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :description
  attribute :price, serializer: PanStuff::Serializer::MoneySerializer
  attribute :sale_price, serializer: PanStuff::Serializer::MoneySerializer
end

# Utilizzo
product = Product.new(
  id: 1,
  name: "Laptop",
  price: Money.new(99999, "EUR"),
  sale_price: Money.new(79999, "EUR")
)

ProductSerializer.new(product).to_h
# => {
#   data: {
#     id: 1,
#     name: "Laptop",
#     description: "...",
#     price: {
#       cents: 99999,
#       amount: 999.99,
#       currency: "EUR",
#       formattedText: "€ 999.99",
#       symbol: "€"
#     },
#     salePrice: {
#       cents: 79999,
#       amount: 799.99,
#       currency: "EUR",
#       formattedText: "€ 799.99",
#       symbol: "€"
#     }
#   }
# }
```

## Esempi Pratici

### E-commerce: Prodotto con Prezzi

```ruby
class ProductPriceSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :regular_price, serializer: MoneySerializer
  attribute :sale_price, serializer: MoneySerializer, serialize_if: ->(context) { context[:show_sale_price] }
  attribute :discount_amount, method: :calculate_discount

  private

  def calculate_discount(product)
    return nil unless product.sale_price

    discount = product.regular_price - product.sale_price
    MoneySerializer.new(discount, root: false).to_h
  end
end
```

### Ordine con Calcoli

```ruby
class OrderSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :status
  attribute :subtotal, serializer: MoneySerializer
  attribute :tax_amount, serializer: MoneySerializer
  attribute :shipping_cost, serializer: MoneySerializer
  attribute :discount_amount, serializer: MoneySerializer
  attribute :total, serializer: MoneySerializer
  attribute :items, serializer: OrderItemSerializer
end

class OrderItemSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :product_id
  attribute :quantity
  attribute :unit_price, serializer: MoneySerializer
  attribute :line_total, serializer: MoneySerializer
end
```

### Report Finanziario

```ruby
class FinancialSummarySerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :period
  attribute :total_revenue, serializer: MoneySerializer
  attribute :total_expenses, serializer: MoneySerializer
  attribute :net_profit, serializer: MoneySerializer
  attribute :breakdown, method: :financial_breakdown

  private

  def financial_breakdown(summary)
    {
      revenue_by_category: summary.revenue_breakdown.transform_values do |amount|
        MoneySerializer.new(amount, root: false).to_h
      end,
      expenses_by_type: summary.expense_breakdown.transform_values do |amount|
        MoneySerializer.new(amount, root: false).to_h
      end
    }
  end
end
```

## Inizializzazione

```ruby
# Oggetto Money singolo
MoneySerializer.new(money_object)

# Con metadati
MoneySerializer.new(money_object, meta: { currency_rate: 1.18 })

# Con messaggio
MoneySerializer.new(money_object, message: "Prezzo aggiornato")

# Con context
MoneySerializer.new(money_object, context: { locale: :it })

# Senza root (per uso in serializzatori annidati)
MoneySerializer.new(money_object, root: false)
```

## Gestione di Valori Null

```ruby
# Money object nullo
price = nil
serializer = MoneySerializer.new(price)
serializer.to_h
# => { data: nil }

# In un serializzatore con attributo opzionale
class ProductSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :sale_price, serializer: MoneySerializer, serialize_if: ->(context) { context[:resource].sale_price.present? }
end
```

## Personalizzazione della Formattazione

Se hai bisogno di personalizzare la formattazione, puoi estendere il serializzatore:

```ruby
class CustomMoneySerializer < PanStuff::Serializer::MoneySerializer
  def formatted_text(record)
    # Formattazione personalizzata senza spazio
    record.format(symbol: record.currency.symbol)
  end

  # Aggiungi attributi personalizzati
  attribute :formatted_no_symbol, method: :amount_without_symbol

  private

  def amount_without_symbol(record)
    record.format(symbol: false)
  end
end
```

## Integrazione con API Esterne

### Conversione di Valuta

```ruby
class CurrencyConversionService
  def convert_price(money, target_currency)
    # Logica di conversione (usando API esterna o tassi cached)
    rate = get_exchange_rate(money.currency.iso_code, target_currency)
    converted_amount = (money.cents * rate).round
    Money.new(converted_amount, target_currency)
  end
end

class MultiCurrencyProductSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :price_original, serializer: MoneySerializer
  attribute :price_converted, method: :convert_price_for_user

  private

  def convert_price_for_user(product)
    target_currency = context[:user_currency] || "EUR"
    return nil if product.price.currency.iso_code == target_currency

    converted = CurrencyConversionService.new.convert_price(product.price, target_currency)
    MoneySerializer.new(converted, root: false).to_h
  end
end
```

## Best Practices

1. **Usa per Tutti gli Importi**: Serializza sempre gli oggetti Money con questo serializzatore per consistenza
2. **Root False per Annidati**: Usa `root: false` quando includi in altri serializzatori
3. **Gestione Null**: Controlla sempre la presenza dell'oggetto Money prima della serializzazione
4. **Valute Consistenti**: Assicurati che le valute siano valide e supportate
5. **Performance**: Per molti oggetti Money, considera la cache dei tassi di cambio

## Attributi Disponibili

| Attributo        | Tipo    | Descrizione         | Esempio    |
| ---------------- | ------- | ------------------- | ---------- |
| `cents`          | Integer | Valore in centesimi | 99999      |
| `amount`         | Float   | Valore decimale     | 999.99     |
| `currency`       | String  | Codice ISO valuta   | "EUR"      |
| `formatted_text` | String  | Testo formattato    | "€ 999.99" |
| `symbol`         | String  | Simbolo valuta      | "€"        |

## Troubleshooting

### Oggetto Money Non Valido

- Verifica che l'oggetto sia un'istanza di `Money`
- Controlla che la valuta sia supportata dalla gem Money

### Formattazione Incorretta

- Assicurati che la gem Money sia configurata correttamente
- Verifica le impostazioni di locale se necessario

### Performance Issues

- Per grandi quantità di oggetti Money, considera la serializzazione batch
- Usa cache per tassi di cambio se fai conversioni

### Errori di Precisione

- Gli oggetti Money gestiscono automaticamente la precisione
- Evita conversioni manuali da float a Money per prevenire errori di arrotondamento
