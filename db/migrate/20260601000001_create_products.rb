class CreateProducts < ActiveRecord::Migration[7.2]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.text :description
      t.string :sku, null: false
      t.bigint :price_cents, null: false
      t.integer :stock, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :products, :sku, unique: true
    add_index :products, [:active, :id]
    add_check_constraint :products, "stock >= 0", name: "products_stock_nonnegative"
    add_check_constraint :products, "price_cents >= 0", name: "products_price_nonnegative"
  end
end
