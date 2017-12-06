require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'sinatra/json'
require 'sinatra/config_file'
require 'rugged'

require_relative "./git_service"

# Used by Marathon healthcheck
get "/status" do
  json(status: :live)
end

post "/trigger" do
  GitService.init()

  json(status: :success)
end
