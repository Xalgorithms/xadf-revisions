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
require 'multi_json'

require_relative '../libs/local_env'

module Services
  class Cassandra
    LOCAL_ENV = LocalEnv.new(
      'CASSANDRA', {
        hosts:    { type: :list,   default: ['localhost'] },
        keyspace: { type: :string, default: 'xadf' },
      })
    
    def store_effectives(os)
      keys = [:country, :region, :timezone, :starts, :ends, :party, :rule_id]
      within_batch do
        build_inserts('xadf.effective', keys, os)
      end
    end

    def store_whens(os)
      within_batch do
        build_inserts('xadf.when_keys', [:section, :key], os) + 
          build_inserts('xadf.whens',  [:section, :key, :op, :val, :rule_id], os)
      end
    end

    private

    def session
      @session ||= connect
    end

    def connect
      begin
        hosts = LOCAL_ENV.get(:hosts)
        keyspace = LOCAL_ENV.get(:keyspace)
        
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
    
    def build_inserts(tn, ks, os)
      os.map do |o|
        avail_ks = ks.select { |k| o.key?(k) && o[k] }
        vals = avail_ks.map { |k| "'#{o[k]}'" }
        "INSERT INTO #{tn} (#{avail_ks.join(',')}) VALUES (#{vals.join(',')})"
      end
    end
    
    def within_batch
      if session
        stms = yield
        if !stms.empty?
          q = 'BEGIN BATCH ' + stms.join(';') + '; APPLY BATCH;'
          stm = session.prepare(q)
          session.execute(stm)
        end
      else
        puts '! no session available'
      end
    end
  end
end
