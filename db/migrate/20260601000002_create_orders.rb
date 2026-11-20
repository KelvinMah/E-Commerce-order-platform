class CreateOrders < ActiveRecord::Migration[7.2]
  def change
    create_table :orders do |t|
      t.string :idempotency_key, null: false
      t.string :request_digest, null: false
      t.string :email, null: false
      t.string :status, null: false, default: "confirmed"
      t.bigint :total_cents, null: false
      t.datetime :cancelled_at
      t.timestamps
    end
    add_index :orders, :idempotency_key, unique: true
    add_index :orders, :email
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.bigint :unit_price_cents, null: false
      t.timestamps
    end
    add_index :order_items, [:order_id, :product_id], unique: true
    add_check_constraint :order_items, "quantity > 0", name: "order_items_quantity_positive"
    create_table :outbox_events do |t|
      t.references :order, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :status, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.datetime :processed_at
      t.timestamps
    end
    add_index :outbox_events, [:order_id, :kind], unique: true
    add_index :outbox_events, [:status, :id]
    create_table :delivery_receipts do |t|
      t.references :outbox_event, null: false, foreign_key: true, index: { unique: true }
      t.string :channel, null: false
      t.string :destination, null: false
      t.datetime :delivered_at, null: false
      t.timestamps
    end
  end
end
