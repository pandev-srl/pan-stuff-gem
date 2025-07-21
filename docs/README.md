# PanStuff - Documentazione Completa

PanStuff è una gem Ruby che fornisce strumenti avanzati per lo sviluppo di API Rails, con focus su serializzazione, paginazione e gestione delle risorse.

## Panoramica

La libreria offre:

- **Controller per Risorse**: Pattern standardizzato per operazioni CRUD
- **Sistema di Serializzazione**: Serializzatori flessibili e potenti per API JSON
- **Paginazione**: Strumenti per paginare collezioni ActiveRecord
- **Helper per Parametri**: Utilità per gestire parametri di richiesta
- **Gestione Errori**: Serializzazione standardizzata di errori e validazioni

## Installazione

Aggiungi questa riga al tuo Gemfile:

```ruby
gem "pan_stuff"
```

Esegui:

```bash
bundle install
```

## Guida Rapida

### 1. Controller Base per Risorse

```ruby
class UsersController < ApplicationController
  include PanStuff::ResourcesController

  private

  def resource_service_class
    UserService
  end

  def resource_serializer
    UserSerializer
  end

  def resource_location
    user_path(@resource)
  end

  def resource_params_root_key
    :user
  end
end
```

### 2. Serializzatore Personalizzato

```ruby
class UserSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :id
  attribute :name
  attribute :email
  attribute :created_at
end
```

### 3. Paginazione

```ruby
class User < ApplicationRecord
  include PanStuff::ActiveRecordPagination
end

# Nel controller
users = User.paginate(current_page: 1, items_per_page: 10)
```

## Documentazione Dettagliata

### Controller

- [ResourcesController](controllers/resources-controller.md) - Controller base per operazioni CRUD

### Serializzatori

- [ObjectSerializer](serializers/object-serializer.md) - Serializzatore principale per oggetti
- [HashSerializer](serializers/hash-serializer.md) - Serializzatore per hash
- [SmartHashSerializer](serializers/smart-hash-serializer.md) - Versione intelligente del HashSerializer
- [MoneySerializer](serializers/money-serializer.md) - Serializzatore per oggetti Money
- [ExceptionSerializer](serializers/exception-serializer.md) - Serializzatore per eccezioni
- [ResourceErrorsSerializer](serializers/resource-errors-serializer.md) - Serializzatore per errori
- [ValidationResponseSerializer](serializers/validation-response-serializer.md) - Serializzatore per validazioni

### Paginazione

- [ActiveRecordPagination](pagination/active-record-pagination.md) - Estensione per paginazione
- [Metadata](pagination/metadata.md) - Metadati di paginazione
- [MetadataSerializer](pagination/metadata-serializer.md) - Serializzatore per metadati

### Helper

- [ParamsHelpers](helpers/params-helpers.md) - Helper per parametri di richiesta

### Esempi

- [Utilizzo Base](examples/basic-usage.md) - Esempi di utilizzo base
- [Serializzazione Avanzata](examples/advanced-serialization.md) - Tecniche avanzate
- [Pattern per Controller](examples/controller-patterns.md) - Pattern comuni

## Contribuire

Per contribuire al progetto, consulta le linee guida nel repository principale.

## Licenza

Questa gem è disponibile come open source sotto i termini della [MIT License](https://opensource.org/licenses/MIT).
