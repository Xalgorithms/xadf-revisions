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

  def self.store_effective_rule()
    statement = @session.prepare(
      "INSERT INTO xadf.effective_rules (rule_id) " \
      "VALUES (?)"
    )
    rule_id = new_uuid
    @session.execute(statement, arguments: [rule_id])

    rule_id
  end
end
