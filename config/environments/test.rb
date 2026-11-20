Rails.application.configure do
  config.eager_load = ENV["CI"].present?
  config.consider_all_requests_local = true
  config.action_dispatch.show_exceptions = :none
  config.secret_key_base = "test-secret-key-base-long-enough-for-local-use-only"
end
