# Copyright (C) 2018 Don Kelly <karfai@gmail.com>
# Copyright (C) 2018 Hayk Pilosyan <hayk.pilos@gmail.com>

# This file is part of Interlibr, a functional component of an
# Internet of Rules (IoR).

# ACKNOWLEDGEMENTS
# Funds: Xalgorithms Foundation
# Collaborators: Don Kelly, Joseph Potvin and Bill Olders.

# This program is free software: you can redistribute it and/or
# modify it under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public
# License along with this program. If not, see
# <http://www.gnu.org/licenses/>.
require 'sinatra'
require 'sinatra/json'
require 'sinatra/config_file'

require_relative './services/actions'

if ENV['RACK_ENV'] == 'test'
  disable(:show_exceptions)
end

# Used by Marathon healthcheck
get "/status" do
  json(status: :live)
end

post '/actions' do
  o = JSON.parse(request.body.read)
  Services::Actions.instance.execute(o)
  json(status: 'ok')
end

# post '/repositories' do
#   o = JSON.parse(request.body.read)
#   res = github.get(o['url']) do |packages|
#     documents.store_packages(o['url'], packages)
#   end

#   json(res.merge(status: 'ok'))
# end

# ['rules', 'tables', 'packages'].each do |n|
#   get "/#{n}" do
#     json(documents.all(n))
#   end
  
#   get "/#{n}/:id" do
#   json(documents.one(n, params[:id]))
#   end
# end

# post '/rules' do
#   o = JSON.parse(request.body.read)
  
#   json({ id: documents.store_unpackaged_rule(o) })
# end

# post '/tables' do
#   o = JSON.parse(request.body.read)
#   json({ id: documents.store_unpackaged_table(o) })
# end

post '/events' do
  body = request.body.read
  # we really just need to handle the "push" event - it tells us what we need to know about create/delete.
  # create: { "before"=>"0000000000000000000000000000000000000000", "after"=>"444351339beb58b82a82a946286c3ebe0d2e6460", "created"=>true, "deleted"=>false }
  # delete: { "before"=>"444351339beb58b82a82a946286c3ebe0d2e6460", "after"=>"0000000000000000000000000000000000000000", "created"=>false, "deleted"=>true }
  #

  if !request.env.key?('HTTP_X_HUB_SIGNATURE') || !verify(body, request.env['HTTP_X_HUB_SIGNATURE'])
    status(403)
    json(status: 'failed_signature', reason: 'incorrect signature')
    halt
  end

  event = request.env['HTTP_X_GITHUB_EVENT']
  if event != 'push'
    status(403)
    json(status: 'failed_unknown_event', reason: "event is not handled (event=#{event})")
    halt
  end
  
  o = JSON.parse(body)
  Services::Actions.instance.execute(name: 'update', thing: 'repository', args: o)
  json(status: 'ok')
end

def verify(body, request_sig)
  sig = "sha1=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['GITHUB_SECRET'], body)}"
  Rack::Utils.secure_compare(sig, request_sig)
end
