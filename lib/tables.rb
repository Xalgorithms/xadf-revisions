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
require 'cassandra'

require_relative './local_env'

class Tables
  def initialize
    @env = LocalEnv.new(
      'CASSANDRA', {
        hosts:    { type: :list,   default: ['localhost'] },
        keyspace: { type: :string, default: 'interlibr' },
      })
  end

  def store_applicables(apps)
    within_batch do
      build_inserts('when_keys', [:section, :key], apps) + 
        build_inserts('whens',  [:section, :key, :op, :val, :rule_id], apps)
    end
  end
  
  def store_effectives(effs)
    keys = [:country, :region, :timezone, :starts, :ends, :key, :rule_id]
    within_batch do
      build_inserts('effective', keys, effs)
    end
  end

  def store_meta(meta)
    keys = [:ns, :name, :origin, :branch, :rule_id, :version, :runtime, :criticality]
    execute do
      "#{build_insert('rules', keys, meta)};"
    end
  end
  
  private

  def build_insert(tn, ks, o)
    keyspace = @env.get(:keyspace)
    avail_ks = ks.select { |k| o.key?(k) && o[k] }
    vals = avail_ks.map { |k| "'#{o[k]}'" }
    avail_ks.empty? ? '' : "INSERT INTO #{keyspace}.#{tn} (#{avail_ks.join(',')}) VALUES (#{vals.join(',')})"
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
        p q
        stm = session.prepare(q)
        session.execute(stm)
      else
        puts "! no generated statement"
      end
    else
      puts '! no session available'
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
