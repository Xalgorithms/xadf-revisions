require 'sidekiq'
require_relative '../services/github'

$github = Services::GitHub.new

module Jobs
  class AddRepo
    include Sidekiq::Worker

    def perform(o)
      url = o.fetch('url', nil)
      if url
        puts "> fetching (url=#{url})"
        res = $github.get(url) do |packages|
          p packages
        end
        p res
      else
        puts "? no url provided"
      end
    end
  end
end
