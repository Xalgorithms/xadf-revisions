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

  def self.store_rule(key, rule)
    collection = @database["rules"]
    doc = {_key: key}.merge({items: rule})
    puts doc
    res = collection.create_document(document: doc)

    res.key
  end
end
