class CreateExampleEntities < ActiveRecord::Migration[7.2]
  def change
    create_table :example_entities do |t|
      t.string :name
      t.string :surname

      t.timestamps
    end
  end
end
