require "rails_helper"
RSpec.describe "Commerce API", type: :request do
  let!(:product) { Product.create!(name: "Desk lamp", sku: "LAMP-1", price_cents: 4500, stock: 3) }
  let(:payload) { { email: "Buyer@example.com", items: [{ product_id: product.id, quantity: 2 }] } }
  let(:headers) { { "Idempotency-Key" => "checkout-123" } }

  it "lists products and supports search" do
    get "/api/products", params: { q: "lamp" }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("products").map { |p| p.fetch("sku") }).to include("LAMP-1")
  end
  it "creates an order, decrements stock, and writes three outbox events" do
    post "/api/orders", params: payload, headers: headers, as: :json
    expect(response).to have_http_status(:created)
    expect(response.parsed_body.fetch("total_cents")).to eq(9000)
    expect(product.reload.stock).to eq(1)
    expect(OutboxEvent.count).to eq(3)
  end
  it "returns the same order on a retried idempotency key without deducting stock twice" do
    2.times { post "/api/orders", params: payload, headers: headers, as: :json; expect(response).to have_http_status(:created) }
    expect(Order.count).to eq(1)
    expect(product.reload.stock).to eq(1)
  end
  it "rejects a reused key with a different cart" do
    post "/api/orders", params: payload, headers: headers, as: :json
    post "/api/orders", params: payload.merge(items: [{ product_id: product.id, quantity: 1 }]), headers: headers, as: :json
    expect(response).to have_http_status(:conflict)
  end
  it "rejects insufficient inventory without creating an order" do
    post "/api/orders", params: payload.merge(items: [{ product_id: product.id, quantity: 4 }]), headers: headers, as: :json
    expect(response).to have_http_status(:conflict)
    expect(Order.count).to eq(0)
    expect(product.reload.stock).to eq(3)
  end
  it "cancels once and restores stock once" do
    post "/api/orders", params: payload, headers: headers, as: :json
    id = response.parsed_body.fetch("id")
    2.times { post "/api/orders/#{id}/cancel"; expect(response).to have_http_status(:ok) }
    expect(product.reload.stock).to eq(3)
    expect(Order.find(id).status).to eq("cancelled")
  end
  it "loads order details with items" do
    post "/api/orders", params: payload, headers: headers, as: :json
    get "/api/orders/#{response.parsed_body.fetch('id')}"
    expect(response.parsed_body.fetch("items").first.fetch("name")).to eq("Desk lamp")
  end
end
