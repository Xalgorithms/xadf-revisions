require 'csv'
require 'digest'
require 'mongo'
require 'multi_json'
require 'xa/rules/parse'
require 'uuid'

module Services
  class Documents
    include XA::Rules::Parse
    
    def initialize(opts, subscribers={})
      @cl = Mongo::Client.new(opts['url'])
      @subscribers = subscribers
    end
    
    def store_packages(origin_url, pkgs)
      ids = { }

      pkgs.each do |pkg_name, pkg|
        store_thing(origin_url, pkg_name, pkg, 'rules') do |content|
          parse(content)
        end
        store_thing(origin_url, pkg_name, pkg, 'tables') do |content|
          { table: CSV.parse(content) }
        end
      end
    end
    
    private
    
    def store_thing(origin_url, pkg_name, pkg, pkg_section)
      @things ||= {
        'rules'  => { 'prefix' => 'R', 'collection' => 'rules' },
        'tables' => { 'prefix' => 'T', 'collection' => 'tables' },
      }
      pkg.fetch(pkg_section, {}).each do |thing_name, thing|
        id = build_id(@things[pkg_section]['prefix'], pkg_name, thing_name, thing['version'])
        store_document('meta', id, thing.merge(name: thing_name, package: pkg_name, origin_url: origin_url))
        store_document(@things[pkg_section]['collection'], id, yield(thing.fetch('content', '')))
      end
    end

    def store_document(cn, id, doc)
      @cl[cn].insert_one(doc.merge(public_id: id))
      fn = @subscribers.fetch(cn, nil)
      if fn
        fn.call(id)
      end
    end
    
    def build_id(prefix, pkg_name, thing_name, thing_ver)
      Digest::SHA1.hexdigest("#{prefix}(#{pkg_name}:#{thing_name}:#{thing_ver})")
    end
  end
end
