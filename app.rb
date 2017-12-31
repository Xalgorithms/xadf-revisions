require 'sinatra'
require 'sinatra/json'
require 'sinatra/config_file'

require_relative './services/github'

config_file 'config.yml'

# Used by Marathon healthcheck
get "/status" do
  json(status: :live)
end

github = Services::GitHub.new

post '/repositories' do
  o = JSON.parse(request.body.read)
  github.process(o['url']) do |packages|
  end

  json(status: 'ok')
end
