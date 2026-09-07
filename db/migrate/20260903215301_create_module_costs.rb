class CreateModuleCosts < ActiveRecord::Migration[8.0]
  def change
    create_table :module_costs do |t|
      t.string :layer, null: false
      t.integer :cost_in_credits, null: false

      t.timestamps
    end
    add_index :module_costs, :layer, unique: true
  end
end
