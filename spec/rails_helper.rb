ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rspec/rails"
require_relative "spec_helper"
ActiveRecord::Migration.maintain_test_schema!
RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.before { allow(DispatchOutboxJob).to receive(:perform_async) }
  config.around(:each, :concurrency) do |example|
    previous = RSpec.configuration.use_transactional_fixtures
    RSpec.configuration.use_transactional_fixtures = false
    begin
      example.run
    ensure
      RSpec.configuration.use_transactional_fixtures = previous
      # Concurrent examples commit on separate connections; clear their rows afterward.
      DeliveryReceipt.delete_all
      OutboxEvent.delete_all
      OrderItem.delete_all
      Order.delete_all
      Product.delete_all
    end
  end
end
