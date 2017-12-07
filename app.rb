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

  type = tag["ref_type"]

  # The same 'Create' hook is responsible for both
  # branch and tag creation. Ignore new branches
  if type == "branch"
    halt 404, "Not found"
  end

  repo = tag["repository"]
  clone_url = repo["clone_url"]
  repo_name = repo["name"]
  success = GitService.init(clone_url, repo_name)

  json(success: success)
end
