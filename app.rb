require 'sinatra'
require 'sinatra/json'
require 'sinatra/config_file'

require_relative './services/cassandra'
require_relative './services/documents'
require_relative './services/github'
require_relative './services/translate'

# Used by Marathon healthcheck
get "/status" do
  json(status: :live)
end

github = Services::GitHub.new
cassandra = Services::Cassandra.new()
documents = Services::Documents.new()
translate = Services::Translate.new(documents, cassandra)

post '/repositories' do
  o = JSON.parse(request.body.read)
  res = github.get(o['url']) do |packages|
    documents.store_packages(o['url'], packages)
  end

  json(res.merge(status: 'ok'))
end

get '/rules' do
  json(documents.all('rules'))
end

get '/rules/:id' do
  json(documents.one('rules', params[:id]))
end

get '/tables' do
  json(documents.all('tables'))
end

get '/packages' do
  json(documents.all('packages'))
end

post '/events' do
  body = request.body.read
  if verify(body, request.env['HTTP_X_HUB_SIGNATURE'])
    event = request.env['HTTP_X_GITHUB_EVENT']
    o = JSON.parse(body)

    res = github.event(event, o) do |event|
      case event[:action]
      when :update
        documents.store_packages(event[:url], event[:packages])
      when :delete
        documents.remove_revision(event[:url], event[:revision])
      end
    end
    
    json((res || {}).merge(status: 'ok'))
  else
    status(403)
    json(status: 'failed', reason: 'incorrect signature')
  end
end

def verify(body, request_sig)
  sig = "sha1=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['GITHUB_SECRET'], body)}"
  Rack::Utils.secure_compare(sig, request_sig)
end
