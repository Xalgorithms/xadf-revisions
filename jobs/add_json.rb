require 'sidekiq'

module Jobs
  class AddJson
    include Sidekiq::Worker

    def perform(o)
      p [:add_json, o]
      false
    end
  end
end
