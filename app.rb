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
  res = github.process(o['url']) do |packages|
    documents.store_packages(o['url'], packages)
  end

  json(res.merge(status: 'ok'))
end

post '/events' do
  body = request.body.read
  if verify(body, request.env['HTTP_X_HUB_SIGNATURE'])
    event = request.env['HTTP_X_GITHUB_EVENT']
    o = JSON.parse(body)

    github.event(event, o) do |packages|
      
    end
    
    json(status: 'ok')
  else
    status(403)
    json(status: 'failed', reason: 'incorrect signature')
  end
end

def verify(body, request_sig)
  sig = "sha1=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['GITHUB_SECRET'], body)}"
  Rack::Utils.secure_compare(sig, request_sig)
end
