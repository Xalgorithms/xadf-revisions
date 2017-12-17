require "cassandra"

class CassandraService
  @session = nil

  def self.init()
    cluster = Cassandra.cluster(
      hosts: Sinatra::Application.settings.db_hosts,
      port: Sinatra::Application.settings.db_port
    )
    @session  = cluster.connect(Sinatra::Application.settings.db_keyspace)
  end

  def self.new_uuid()
    generator = Cassandra::Uuid::Generator.new
    generator.uuid
  end

  def self.store_effective_rule(meta)
    rule_id = new_uuid
    country = meta['jurisdiction']['country']
    region = meta['jurisdiction']['region']
    timezone = meta['effective'][0]['timezone']
    starts = meta['effective'][0]['starts']
    ends = meta['effective'][0]['ends']

    statement = @session.prepare('INSERT INTO xadf.effective_rules JSON ?')

    data = {
      rule_id: rule_id,
      country: country,
      region: region,
      timezone: timezone,
      starts: starts,
      ends: ends
    }

    @session.execute(statement, arguments: [data.to_json])

    rule_id
  end
end
