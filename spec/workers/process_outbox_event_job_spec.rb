require "rails_helper"
RSpec.describe ProcessOutboxEventJob do
  it "persists one receipt when retried" do
    p = Product.create!(name: "Chair", sku: "CHAIR", price_cents: 1000, stock: 10)
    order = CheckoutService.new(email: "test@example.com", idempotency_key: "unique", items: [{ product_id: p.id, quantity: 1 }]).call
    event = order.outbox_events.find_by!(kind: "confirmation")
    3.times { described_class.new.perform(event.id) }
    expect(DeliveryReceipt.where(outbox_event_id: event.id).count).to eq(1)
    expect(event.reload.status).to eq("processed")
  end
end
