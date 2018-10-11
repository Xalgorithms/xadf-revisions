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
require 'active_support/core_ext/string'
require 'mongo'

require_relative './local_env'
require_relative './local_logger'

class Documents
  def initialize
    @env = LocalEnv.new(
      'MONGO', {
        url: { type: :string, default: 'mongodb://127.0.0.1:27017/interlibr' },
      })
  end

  def store_rule(t, id, meta, doc)
    #public_id = make_id(t, src.merge('version' => doc.fetch('meta', {}).fetch('version', nil)))
    connection['rules'].insert_one(meta.merge(content: doc, public_id: id, thing: t))
  end

  def store_table_data(rule_id, content)
    connection['table_data'].insert_one(rule_id: rule_id, content: content)
  end

  def remove_rules_by_origin_branch(origin, branch)
    delete_many_by_origin_branch('rules', origin, branch)
  end

  def remove_rule_by_id(rule_id)
    connection['rules'].delete_many(public_id: rule_id)
  end

  def remove_table_data_by_origin_branch(origin, branch)
    delete_many_by_origin_branch('table_data', origin, branch)
  end

  def remove_specific_table_data(origin, branch, ns, name)
    connection['table_data'].delete_many(origin: origin, branch: branch, ns: ns, name: name)
  end
  
  def lookup_rule_branches(rule_id)
    connection['rules'].find(public_id: rule_id).map(&method(:extract_branch_origin))
  end

  private

  def extract_branch_origin(o)
    {
      origin: o.fetch('origin', nil),
      branch: o.fetch('branch', nil),
      id: o.fetch('public_id', nil),
    }
  end
  
  def delete_many_by_origin_branch(cn, origin, branch)
    connection[cn].delete_many(origin: origin, branch: branch)
  end

  def connection
    @cl ||= connect
  end

  def connect
    if ENV.fetch('RACK_ENV', 'development') == 'test'
      raise 'specs should not be running real Mongo connections'
    end
    
    url = @env.get(:url)
    
    LocalLogger.give('connecting to Mongo', url: url)
    cl = Mongo::Client.new(url)
    LocalLogger.got('connected to Mongo', url: url)

    cl
  end

  def store_thing(t, src, doc)
  end
end
