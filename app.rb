require 'sinatra'
require 'sinatra/json'
require 'sinatra/config_file'

require_relative './services/cassandra'
require_relative './services/documents'
require_relative './services/github'
require_relative './services/translate'

config_file 'config.yml'

# Used by Marathon healthcheck
get "/status" do
  json(status: :live)
end

github = Services::GitHub.new
cassandra = Services::Cassandra.new(settings.cassandra)
documents = Services::Documents.new(settings.mongo)
translate = Services::Translate.new(documents, cassandra)

post '/repositories' do
  o = JSON.parse(request.body.read)
  github.process(o['url']) do |packages|
    documents.store_packages(o['url'], packages)
  end

  json(status: 'ok')
end
