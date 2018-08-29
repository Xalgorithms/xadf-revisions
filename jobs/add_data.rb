require 'sidekiq'

module Jobs
  class AddData
    include Sidekiq::Worker

    def perform(o)
      p [:add_data, o]
      false
    end
  end
end
