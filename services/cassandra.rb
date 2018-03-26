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
    
    def initialize()
      begin
        hosts = LOCAL_ENV.get(:hosts)
        keyspace = LOCAL_ENV.get(:keyspace)
        
        puts "# discovering cluster (hosts=#{hosts})"
        cluster = ::Cassandra.cluster(hosts: hosts)

        puts "# connecting to keyspace (keyspace=#{keyspace})"
        @session = cluster.connect(keyspace)
      rescue ::Cassandra::Errors::NoHostsAvailable => e
        puts '! no available Cassandra instance'
        p e
      rescue ::Cassandra::Errors::IOError => e
        puts '! failed to connect to cassandra'
        p e
      rescue ::Cassandra::Errors::InvalidError => e
        puts '! failed to connect to cassandra'
        p e
      end
    end

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

    def build_inserts(tn, ks, os)
      os.map do |o|
        avail_ks = ks.select { |k| o.key?(k) && o[k] }
        vals = avail_ks.map { |k| "'#{o[k]}'" }
        "INSERT INTO #{tn} (#{avail_ks.join(',')}) VALUES (#{vals.join(',')})"
      end.join('; ') + ';'
    end
    
    def within_batch
      if @session
        q = 'BEGIN BATCH ' + yield + ' APPLY BATCH;'
        stm = @session.prepare(q)
        @session.execute(stm)
      else
        puts '! no session available'
      end
    end
  end
end