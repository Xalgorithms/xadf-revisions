require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'sinatra/json'
require 'sinatra/config_file'
require 'rugged'

require_relative "./services/git_service"

# Used by Marathon healthcheck
get "/status" do
  json(status: :live)
end

post "/tag" do
  tag = JSON.parse(request.body.read)
  clone_url = tag["clone_url"]
  repo_name = tag["repository"]["name"]
  success = GitService.init(clone_url, repo_name)

  json(success: success)
end
