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

  def self.extract_when_keys(d)
    res = d.inject({}) do |accum, w|
      whens = w["whens"]
      whens.each do |key, arr|
        if (!accum.key?(key))
          accum[key] = []
        end
        arr.each do |expr|
          accum[key].push({
            key: expr["expr"]["left"]["value"],
            value: expr["expr"]["right"]["value"],
            op: expr["expr"]["op"]
          })
        end
      end

      accum
    end

    res
  end

  def self.store_when_keys(d)
    sections = extract_when_keys(d)
    sections.each do |section, arr|
      query = "BEGIN BATCH "
      arr.each do |o|
        query = query + "INSERT INTO xadf.when_keys (section, key) VALUES('#{section}', '#{o[:key]}') IF NOT EXISTS;"
      end
      query = query + "APPLY BATCH;"

      statement = @session.prepare(query)
      @session.execute(statement)
    end
  end

  def self.store_whens(id, d)
    sections = extract_when_keys(d)
    sections.each do |section, arr|
      query = "BEGIN BATCH "
      arr.each do |o|
        query = query + "INSERT INTO xadf.whens (rule_id, section, key, operator, value) VALUES('#{id}', '#{section}', '#{o[:key]}', '#{o[:op]}', '#{o[:value]}');"
      end
      query = query + "APPLY BATCH;"

      statement = @session.prepare(query)
      @session.execute(statement)
    end
  end
end
