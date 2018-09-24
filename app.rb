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
  begin
    o = JSON.parse(request.body.read)
    Services::Actions.instance.execute(o)
    json(status: 'ok')
  rescue JSON::ParserError => e
    status(500)
    json(status: 'failed_parse', reason: 'The supplied body was not valid JSON')
  end
end

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

def determine_branch(gho)
  gho.fetch('ref', '').split('/').last
end

def determine_url(gho)
  gho.fetch('repository', {}).fetch('clone_url')
end

def determine_what_happened(gho)
  created = gho.fetch('created', false)
  deleted = gho.fetch('deleted', false)

  if created
    'branch_created'
  elsif deleted
    'branch_removed'
  else
    'branch_updated'
  end
end

def determine_changes(gho)
  pcid = gho.fetch('before', nil)
  gho.fetch('commits', []).map do |co|
    cid = co.fetch('id', '')
    ch = {
      'previous_commit_id' => pcid,
      'commit_id'          => cid,
      'committer'          => {
        'name'  => co['committer']['name'],
        'email' => co['committer']['email'],
      }
    }
    
    ch = ['added', 'removed', 'modified'].inject(ch) do |o, k|
      fns = co.fetch(k, [])
      fns.any? ? o.merge(k => fns) : o
    end

    pcid = cid

    ch
  end
end

# NOTE: all requests following the app -> actions -> (job) path use
# string keys this is not NECESSARY but since SOME of the data comes
# from outside JSON requests, it is consistency

post '/events' do
  body = request.body.read

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
  
  gho = JSON.parse(body)
  changes = determine_changes(gho)

  args = {
    'branch' => determine_branch(gho),
    'url'    => determine_url(gho),
    'what'   => determine_what_happened(gho),
  }.tap do |args|
    args['changes'] = changes if changes.any?
  end

  Services::Actions.instance.execute('name' => 'update', 'thing' => 'repository', 'args' => args)
  json(status: 'ok')
end

def verify(body, request_sig)
  sig = "sha1=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['GITHUB_SECRET'], body)}"
  Rack::Utils.secure_compare(sig, request_sig)
end
