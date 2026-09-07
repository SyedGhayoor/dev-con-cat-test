class AddTenantFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :account, foreign_key: true, null: true # null only for super_admin
    add_column :users, :role, :string, null: false, default: "member" # super_admin | account_admin | member
    add_column :users, :name, :string, null: false, default: ""
    add_index :users, :role
  end
end
