require 'cassandra'
require 'multi_json'

module Services
  class Cassandra
    def initialize(opts)
      cluster = ::Cassandra.cluster(
        hosts: opts['hosts'],
        port: opts['port'])
      @session = cluster.connect(opts['keyspace'])
    end

    def store_effective(o)
      store_json('xadf.effective', o)
    end

    def store_when_key(o)
      store_json('xadf.when_keys', o)
    end

    def store_when(o)
      store_json('xadf.whens', o)
    end

    private

    def store_json(tn, o)
      stm = @session.prepare("INSERT INTO #{tn} JSON ?")
      @session.execute(stm, arguments: [MultiJson.encode(o)])
    end
  end
end
