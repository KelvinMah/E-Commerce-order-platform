require "rails_helper"
require "securerandom"

RSpec.describe "Concurrent checkout", :concurrency do
  self.use_transactional_tests = false

  it "uses independent PostgreSQL sessions across concurrent workers" do
    pids = race(8) do |_i|
      ActiveRecord::Base.connection.select_value("SELECT pg_backend_pid()")
    end
    expect(pids.map(&:first)).to all(eq(:ok))
    expect(pids.map(&:last).uniq.size).to be > 1
  end

  def race(count, &block)
    gate = Queue.new
    results = Queue.new
    workers = count.times.map do |i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          begin
            results << [:ok, block.call(i)]
          rescue StandardError => e
            results << [:error, e]
          end
        end
      end
    end
    count.times { gate << true }
    workers.each(&:join)
    count.times.map { results.pop }
  end

  it "never oversells when different keys compete for the last units" do
    product = Product.create!(name: "Limited", sku: SecureRandom.hex(12), price_cents: 250, stock: 3)
    results = race(12) do |i|
      CheckoutService.new(email: "test@example.com", idempotency_key: "#{product.id}-#{i}", items: [{ product_id: product.id, quantity: 1 }]).call
    end
    expect(results.count { |status, _| status == :ok }).to eq(3)
    expect(results.select { |status, _| status == :error }.map(&:last)).to all(be_a(CheckoutService::OutOfStock))
    expect(product.reload.stock).to eq(0)
    expect(Order.where(idempotency_key: (0...12).map { |i| "#{product.id}-#{i}" }).count).to eq(3)
  end

  it "returns one order and one set of outbox events for simultaneous identical keys" do
    product = Product.create!(name: "Repeat", sku: SecureRandom.hex(12), price_cents: 250, stock: 20)
    key = "shared-#{SecureRandom.hex(8)}"
    results = race(10) do |_i|
      CheckoutService.new(email: "test@example.com", idempotency_key: key, items: [{ product_id: product.id, quantity: 1 }]).call.id
    end
    expect(results.map(&:first)).to all(eq(:ok))
    expect(results.map(&:last).uniq.length).to eq(1)
    expect(Order.where(idempotency_key: key).count).to eq(1)
    expect(Order.find_by!(idempotency_key: key).outbox_events.count).to eq(3)
    expect(product.reload.stock).to eq(19)
  end
end
