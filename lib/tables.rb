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
require 'active_support/core_ext/hash'
require 'active_support/core_ext/string'
require 'cassandra'

require_relative './ids'
require_relative './local_env'

class Tables
  include Ids
  
  def initialize
    @env = LocalEnv.new(
      'CASSANDRA', {
        hosts:    { type: :list,   default: ['localhost'] },
        keyspace: { type: :string, default: 'interlibr' },
      })
    @any_fn = lambda { |rs| rs.any? }
    @empty_fn = lambda { |rs| rs.empty? }
  end

  def store_applicables(apps)
    within_batch do
      build_inserts('when_keys', [:section, :key], apps) + 
        build_inserts('whens',  [:section, :key, :op, :val, :rule_id], apps)
    end if apps.any?
  end
  
  def store_effectives(effs)
    keys = [:country, :region, :timezone, :starts, :ends, :key, :rule_id]
    within_batch do
      build_inserts('effective', keys, effs)
    end if effs.any?
  end

  def store_meta(o)
    keys = [:ns, :name, :origin, :branch, :rule_id, :version, :runtime, :criticality]
    insert_one('rules', keys, o)
  end
  
  def store_repository(o)
    keys = [:clone_url]
    insert_one('repositories', keys, o)
  end

  def if_has_repository(clone_url, &bl)
    query_repo_presence(clone_url, @any_fn, &bl).join
  end

  def unless_has_repository(clone_url, &bl)
    query_repo_presence(clone_url, @empty_fn, &bl).join
  end

  def if_has_rule(args, &bl)
    query_rule_presence(args, @any_fn, &bl).join
  end
  
  def unless_has_rule(args, &bl)
    query_rule_presence(args, @empty_fn, &bl).join
  end
  
  private

  def insert_one(tbl, keys, o)
    execute do
      "#{build_insert(tbl, keys, o)};"
    end
  end

  def query_repo_presence(clone_url, fn, &bl)
    query_if(
      'repositories',
      fn,
      [:clone_url],
      { clone_url: { type: :string, value: clone_url } },
      &bl)
  end
  
  def query_rule_presence(args, fn, &bl)
    qargs = args.with_indifferent_access
    rule_id = make_id(qargs.fetch('type', 'rule'), qargs)

    query_if(
      'rules',
      fn,
      [:rule_id],
      {
        rule_id: { type: :string, value: rule_id },
        branch: { type: :string, value: qargs.fetch('branch', 'master') },
      },
      &bl)
  end
  
  def query_if(tbl, fn, keys=[], where={}, &bl)
    query_async(tbl, keys, where) do |rs|
      bl.call if bl && fn.call(rs)
    end
  end
  
  def build_insert(tn, ks, o)
    keyspace = @env.get(:keyspace)
    avail_ks = ks.select { |k| o.key?(k) && o[k] }
    vals = avail_ks.map { |k| "'#{o[k]}'" }
    avail_ks.empty? ? '' : "INSERT INTO #{keyspace}.#{tn} (#{avail_ks.join(',')}) VALUES (#{vals.join(',')})"
  end

  def make_value(v)
    case v[:type]
    when :string
      "'#{v[:value]}'"
    else
      v[:value]
    end
  end
  
  def build_select(tbl, keys=nil, where=nil)
    keyspace = @env.get(:keyspace)
    cols = (keys && keys.any?) ? keys.join(',') : '*'
    where_conds = where.map do |k, v|
      "#{k}=#{make_value(v)}"
    end.join(' AND ')
    
    where = where_conds.empty? ? '' : "WHERE #{where_conds}"
    "SELECT #{cols} FROM #{keyspace}.#{tbl} #{where};"
  end
  
  def build_inserts(tn, ks, os)
    os.map do |o|
      build_insert(tn, ks, o)
    end
  end
  
  def connect
    begin
      hosts = @env.get(:hosts)
      keyspace = @env.get(:keyspace)
      
      puts "# discovering cluster (hosts=#{hosts})"
      cluster = ::Cassandra.cluster(hosts: hosts)

      puts "# connecting to keyspace (keyspace=#{keyspace})"
      cluster.connect(keyspace)
    rescue ::Cassandra::Errors::NoHostsAvailable => e
      puts '! no available Cassandra instance'
      p e
      nil
    rescue ::Cassandra::Errors::IOError => e
      puts '! failed to connect to cassandra'
      p e
      nil
    rescue ::Cassandra::Errors::InvalidError => e
      puts '! failed to connect to cassandra'
      p e
      nil
    end
  end

  def execute
    if session
      q = yield
      if !q.empty?
        stm = session.prepare(q)
        session.execute(stm)
      else
        puts "! no generated statement"
      end
    else
      puts '! no session available'
    end
  end

  def query_async(tbl, keys=nil, where=nil, &bl)
    if session
      q = build_select(tbl, keys, where)
      fut = session.execute_async(q)
      fut.on_success do |rs|
        bl.call(rs) if bl
      end
      fut
    end
  end

  def session
    @session ||= connect
  end

  def within_batch
    execute do
      qs = yield
      'BEGIN BATCH ' + qs.join(';') + '; APPLY BATCH;'
    end
  end
end
