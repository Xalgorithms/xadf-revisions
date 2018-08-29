require 'sidekiq'

module Jobs
  class AddTable
    include Sidekiq::Worker

    def perform(o)
      p [:add_table, o]
      false
    end
  end
end
