require "rails_helper"
RSpec.describe CheckoutService do
  it "combines duplicate cart lines and computes totals using server-side prices" do
    p = Product.create!(name: "Chair", sku: "CHAIR-2", price_cents: 1500, stock: 10)
    order = described_class.new(email: "a@example.com", idempotency_key: "test-dup", items: [
      { product_id: p.id, quantity: 2 }, { product_id: p.id, quantity: 3 }
    ]).call
    expect(order.total_cents).to eq(7500)
    expect(order.order_items.first.quantity).to eq(5)
    expect(p.reload.stock).to eq(5)
  end
end
