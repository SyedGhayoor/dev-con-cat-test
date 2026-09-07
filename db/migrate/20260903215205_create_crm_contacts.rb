class CreateCrmContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :crm_contacts do |t|
      t.references :account, null: false, foreign_key: true
      t.string :external_crm_id, null: false
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :phone
      t.datetime :crm_created_at

      t.timestamps
    end
    add_index :crm_contacts, [:account_id, :phone]
    add_index :crm_contacts, [:account_id, :email]
    add_index :crm_contacts, [:account_id, :external_crm_id], unique: true
  end
end
