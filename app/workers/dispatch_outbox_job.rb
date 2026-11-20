class DispatchOutboxJob
  include Sidekiq::Job
  sidekiq_options retry: 10
  def perform
    OutboxEvent.where(status: "pending").order(:id).limit(200).pluck(:id).each do |id|
      ProcessOutboxEventJob.perform_async(id)
    end
  end
end
