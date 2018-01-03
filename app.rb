require 'sinatra'
require 'sinatra/json'
require 'sinatra/config_file'

require_relative './services/github'
require_relative './services/documents'

config_file 'config.yml'

# Used by Marathon healthcheck
get "/status" do
  json(status: :live)
end

github = Services::GitHub.new
documents = Services::Documents.new(settings.mongo)

post '/repositories' do
  o = JSON.parse(request.body.read)
  github.process(o['url']) do |packages|
    documents.store_packages(o['url'], packages)
  end

  json(status: 'ok')
end
