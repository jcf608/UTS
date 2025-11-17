class CreateDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :documents do |t|
      t.string :title, null: false
      t.text :content, null: false
      t.integer :status, default: 0
      t.json :metadata
      t.string :blob_url
      t.string :search_index_id

      t.timestamps
    end

    add_index :documents, :status
    add_index :documents, :created_at
  end
end
