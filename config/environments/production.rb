Rails.application.configure do
  config.eager_load = true
  config.force_ssl = ENV["FORCE_SSL"] == "true"
  config.log_level = :info
  config.secret_key_base = ENV.fetch("SECRET_KEY_BASE")
end
