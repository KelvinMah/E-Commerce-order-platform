require "digest"
class CheckoutService
  class InvalidCart < StandardError; end
  class OutOfStock < StandardError; end
  class KeyConflict < StandardError; end

  def initialize(email:, idempotency_key:, items:)
    @email = email.to_s.strip.downcase
    @key = idempotency_key.to_s.strip
    raise InvalidCart, "Valid email required" unless URI::MailTo::EMAIL_REGEXP.match?(@email)
    raise InvalidCart, "Idempotency-Key required" if @key.empty? || @key.length > 255
    raise InvalidCart, "Cart must be a nonempty array" unless items.is_a?(Array) && items.any?
    @quantities = Hash.new(0)
    items.each do |item|
      id = Integer(item.fetch(:product_id))
      quantity = Integer(item.fetch(:quantity))
      raise InvalidCart, "Quantity must be between 1 and 100" unless quantity.between?(1, 100)
      @quantities[id] += quantity
      raise InvalidCart, "Quantity must be between 1 and 100" if @quantities[id] > 100
    rescue KeyError, ArgumentError, TypeError
      raise InvalidCart, "Invalid cart item"
    end
    @digest = Digest::SHA256.hexdigest(JSON.generate([@email, @quantities.sort]))
  end

  def call
    # Advisory transaction lock serializes attempts with the same key, including before an order exists.
    # PostgreSQL row locks then serialize stock deductions across different keys.
    order = Order.transaction do
      ActiveRecord::Base.connection.execute("SELECT pg_advisory_xact_lock(hashtextextended(#{ActiveRecord::Base.connection.quote(@key)}, 0))")
      existing = Order.find_by(idempotency_key: @key)
      if existing
        raise KeyConflict, "Key was used for a different request" if existing.request_digest != @digest
        existing
      else
        products = Product.where(id: @quantities.keys).order(:id).lock("FOR UPDATE").to_a
        raise InvalidCart, "Unknown product" if products.length != @quantities.length
        products.each do |product|
          raise InvalidCart, "Product unavailable" unless product.active?
          raise OutOfStock, "Insufficient stock for #{product.sku}" if product.stock < @quantities.fetch(product.id)
        end
        total = products.sum { |p| p.price_cents * @quantities.fetch(p.id) }
        created = Order.create!(email: @email, idempotency_key: @key, request_digest: @digest, total_cents: total)
        products.each do |p|
          qty = @quantities.fetch(p.id)
          p.update!(stock: p.stock - qty)
          created.order_items.create!(product: p, quantity: qty, unit_price_cents: p.price_cents)
        end
        %w[confirmation inventory_sync receipt].each { |kind| created.outbox_events.create!(kind: kind) }
        created
      end
    end
    # The outbox is durable even if Redis/Sidekiq is temporarily unavailable.
    DispatchOutboxJob.perform_async if defined?(DispatchOutboxJob)
    order
  rescue Redis::BaseError => e
    Rails.logger.warn("Outbox dispatch deferred: #{e.message}")
    order
  end
end
