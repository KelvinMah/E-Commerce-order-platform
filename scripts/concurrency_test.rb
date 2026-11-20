# Run: THREADS=20 ATTEMPTS=5000 bundle exec rails runner scripts/concurrency_test.rb
require "securerandom"
require "json"
threads = Integer(ENV.fetch("THREADS", "20"))
attempts = Integer(ENV.fetch("ATTEMPTS", "5000"))
initial_stock = Integer(ENV.fetch("STOCK", "1000"))
raise "ATTEMPTS and THREADS must be positive" unless attempts > 0 && threads > 0
product = Product.create!(name: "Concurrency #{SecureRandom.hex(5)}", sku: SecureRandom.hex(12), price_cents: 1000, stock: initial_stock)
errors = Queue.new
successes = Queue.new
# Each group of four attempts shares a key, exercising concurrent idempotency.
# Separate groups compete for a limited stock supply.
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
workers = threads.times.map do |t|
  Thread.new do
    ActiveRecord::Base.connection_pool.with_connection do
      (t...attempts).step(threads) do |i|
        begin
          key = "load-#{product.id}-#{i / 4}"
          order = CheckoutService.new(email: "load@example.com", idempotency_key: key, items: [{ product_id: product.id, quantity: 1 }]).call
          successes << [key, order.id]
        rescue CheckoutService::OutOfStock
          # Expected once inventory runs out.
        rescue StandardError => e
          errors << "#{e.class}: #{e.message}"
        end
      end
    end
  end
end
workers.each(&:join)
observed = []
observed << successes.pop until successes.empty?
unique_orders = Order.where(idempotency_key: observed.map(&:first).uniq).count
order_ids_consistent = observed.group_by(&:first).values.all? { |pairs| pairs.map(&:last).uniq.size == 1 }
remaining = product.reload.stock
result = { attempts: attempts, threads: threads, stock_before: initial_stock,
  stock_after: remaining, successful_responses: observed.size, unique_orders: unique_orders,
  duplicate_responses: observed.size - unique_orders, unexpected_errors: errors.size,
  duration_seconds: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(2),
  invariant_passed: unique_orders + remaining == initial_stock && remaining >= 0 && order_ids_consistent }
puts JSON.pretty_generate(result)
abort "Concurrency test failed: #{errors.size} unexpected errors" unless result[:invariant_passed] && errors.empty?
