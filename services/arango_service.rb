require "arangorb"

class ArangoService
  @database = nil

  def self.init()
    ArangoServer.default_server(
      user: Sinatra::Application.settings.arango_username,
      password: Sinatra::Application.settings.arango_password,
      server: Sinatra::Application.settings.arango_host,
      port: Sinatra::Application.settings.arango_port
    )
    
    ArangoServer.database = Sinatra::Application.settings.arango_db_name
    @database = ArangoDatabase.new.retrieve
  end

  def self.store_new_rule_version(key, rule_id, version, rule)
    if is_new_rule_version?(rule_id, version)
      store_rule key, rule_id, version, rule
    end
  end

  def self.store_rule(key, rule_id, version, rule)
    collection = @database["rules"]
    doc = {_key: key, rule_id: rule_id, version: version}.merge({items: rule})
    res = collection.create_document(document: doc)

    res.key
  end

  def self.get_rule_by_id(id)
    collection = @database["rules"]

    collection.documentMatch match: {"rule_id" => id}
  end

  def self.is_new_rule_version?(rule_id, version)
    rule = get_rule_by_id rule_id
    if rule == "no match"
      return true
    end

    old_version_1, old_version_2, old_version_3 = rule.body["version"].split "."
    new_version_1, new_version_2, new_version_3 = version.split "."

    return new_version_1 >= old_version_1 && new_version_2 >= old_version_2 && new_version_3 > old_version_3
  end
end
