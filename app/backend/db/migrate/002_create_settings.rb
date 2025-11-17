class CreateSettings < ActiveRecord::Migration[7.1]
  def change
    create_table :settings do |t|
      t.string :key, null: false
      t.text :value
      t.text :description
      t.string :category
      t.timestamps
    end

    add_index :settings, :key, unique: true
    add_index :settings, :category
  end
end
