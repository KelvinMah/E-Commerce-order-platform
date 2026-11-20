namespace :outbox do
  desc "Enqueue pending outbox events; run periodically in production"
  task dispatch: :environment do
    DispatchOutboxJob.perform_async
  end
end
