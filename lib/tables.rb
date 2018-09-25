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

require_relative './local_env'

class Tables
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
    if apps.any?
      execute_when_keys_updates(apps, '+1')

      within_batch do
        build_inserts('whens',  [:section, :key, :op, :val, :rule_id], apps)
      end
    end
  end

  def remove_applicable(rule_id)
    query_data('whens', ['section', 'key'], {
                  rule_id: { type: :string, value: rule_id },
               }) do |section, key|

      execute_when_keys_updates([{ section: section, key: key}], '-1')
    end.join
    execute do
      build_delete('whens', "rule_id='#{rule_id}'")
    end
  end

  def store_effectives(effs)
    keys = [:country, :region, :timezone, :starts, :ends, :key, :rule_id]
    within_batch do
      build_inserts('effective', keys, effs)
    end if effs.any?
  end

  def remove_effective(rule_id)
    execute do
      build_delete('effective', "rule_id='#{rule_id}'")
    end
  end
  
  def store_meta(o)
    keyspace = @env.get(:keyspace)
    keys = [:ns, :name, :origin, :branch, :rule_id, :version, :runtime, :criticality]
    insert_one('rules', keys, o)
    execute do
      "UPDATE #{keyspace}.rules_in_use SET refs=refs+1 WHERE rule_id='#{o[:rule_id]}'"
    end if o.key?(:rule_id)
  end

  def remove_meta(origin, branch, rule_id)
    keyspace = @env.get(:keyspace)
    execute do
      build_delete('rules', "origin='#{origin}' AND branch='#{branch}' AND rule_id='#{rule_id}'")
    end
    execute do
      "UPDATE #{keyspace}.rules_in_use SET refs=refs-1 WHERE rule_id='#{rule_id}'"
    end
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

  def if_has_rule(rule_id, branch, &bl)
    query_rule_presence(rule_id, branch, @any_fn, &bl).join
  end
  
  def unless_has_rule(rule_id, branch, &bl)
    query_rule_presence(rule_id, branch, @empty_fn, &bl).join
  end

  def if_rule_in_use(rule_id, &bl)
    query_rule_use(rule_id) do |count|
      bl.call if count > 0
    end.join if bl
  end

  def unless_rule_in_use(rule_id, &bl)
    query_rule_use(rule_id) do |count|
      bl.call if count == 0
    end.join if bl
  end

  def lookup_rules_in_repo(url, branch, &bl)
    query_data('rules', ['rule_id'], {
                  origin: { type: :string, value: url },
                  branch: { type: :string, value: branch },
                }, &bl).join
  end
  
  private

  def insert_one(tbl, keys, o)
    execute do
      "#{build_insert(tbl, keys, o)};"
    end
  end

  def query_rule_use(rule_id, &bl)
    query_data('rules_in_use', ['refs'], {
                 rule_id: { type: :string, value: rule_id },
               }, &bl)
  end
  
  def query_repo_presence(clone_url, fn, &bl)
    query_if(
      'repositories',
      fn,
      [:clone_url],
      { clone_url: { type: :string, value: clone_url } },
      &bl)
  end
  
  def query_rule_presence(rule_id, branch, fn, &bl)
    query_if(
      'rules',
      fn,
      [:rule_id],
      {
        rule_id: { type: :string, value: rule_id },
        branch: { type: :string, value: branch },
      },
      &bl)
  end
  
  def query_if(tbl, fn, keys=[], where={}, &bl)
    query_async(tbl, keys, where) do |rs|
      bl.call if bl && fn.call(rs)
    end
  end

  def query_data(tbl, keys=[], where={}, &bl)
    query_async(tbl, keys, where) do |rs|
      rs.rows.each do |row|
        args = keys.map { |k| row[k] }
        bl.call(*args)
      end
    end
  end
  
  def build_insert(tn, ks, o)
    keyspace = @env.get(:keyspace)
    avail_ks = ks.select { |k| o.key?(k) && o[k] }
    vals = avail_ks.map { |k| "'#{o[k]}'" }
    avail_ks.empty? ? '' : "INSERT INTO #{keyspace}.#{tn} (#{avail_ks.join(',')}) VALUES (#{vals.join(',')})"
  end

  def build_delete(tbl, cond)
    keyspace = @env.get(:keyspace)
    "DELETE FROM #{keyspace}.#{tbl} WHERE #{cond}"
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
    if ENV.fetch('RACK_ENV', 'development') == 'test'
      raise 'specs should not be running real Cassandra connections'
    end
    
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

  def execute_when_keys_updates(os, inc)
    keyspace = @env.get(:keyspace)
    os.each do |o|
      execute do
        "UPDATE #{keyspace}.when_keys SET refs=refs#{inc} WHERE section='#{o[:section]}' AND key='#{o[:key]}'"
      end
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
