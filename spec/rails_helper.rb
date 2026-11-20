ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rspec/rails"
require_relative "spec_helper"
ActiveRecord::Migration.maintain_test_schema!
RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.before { allow(DispatchOutboxJob).to receive(:perform_async) }
  config.after(:each, :concurrency) do
    DeliveryReceipt.delete_all
    OutboxEvent.delete_all
    OrderItem.delete_all
    Order.delete_all
    Product.delete_all
  end
end
