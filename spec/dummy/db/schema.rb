# frozen_string_literal: true

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 20_240_923_124_655) do
  create_table 'example_entities', force: :cascade do |t|
    t.string 'name'
    t.string 'surname'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
  end

  create_table 'related_objects', force: :cascade do |t|
    t.string 'name'
    t.integer 'example_entity_id'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['example_entity_id'], name: 'index_related_objects_on_example_entity_id'
  end
end
