class CreatePixels < ActiveRecord::Migration[8.0]
  def change
    create_table :pixels do |t|
      t.references :account, null: false, foreign_key: true
      t.string :public_id, null: false # e.g. "px_9f2a01" -- goes in the public snippet
      t.string :name, null: false
      t.string :allowed_landing_pages, array: true, null: false, default: []
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :pixels, :public_id, unique: true
  end
end
