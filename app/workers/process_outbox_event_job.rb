class ProcessOutboxEventJob
  include Sidekiq::Job
  sidekiq_options retry: 15
  def perform(event_id)
    OutboxEvent.transaction do
      event = OutboxEvent.lock.find(event_id)
      return if event.status == "processed"
      event.increment!(:attempts)
      # This local delivery adapter persists a unique receipt, proving idempotent side effects.
      # Replace with a provider supporting idempotency keys before sending real email or webhook requests.
      destination = event.kind == "inventory_sync" ? "inventory-system" : event.order.email
      event.create_delivery_receipt!(channel: event.kind, destination: destination, delivered_at: Time.current) unless event.delivery_receipt
      event.update!(status: "processed", processed_at: Time.current)
    end
  end
end
