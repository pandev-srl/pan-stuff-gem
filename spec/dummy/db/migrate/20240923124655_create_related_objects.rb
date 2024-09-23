# frozen_string_literal: true

class CreateRelatedObjects < ActiveRecord::Migration[7.2]
  def change
    create_table :related_objects do |t|
      t.string :name
      t.references :example_entity

      t.timestamps
    end
  end
end
