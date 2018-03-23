require 'active_support/core_ext/hash'
require 'csv'
require 'digest'
require 'mongo'
require 'multi_json'
require 'xa/rules/parse'
require 'uuid'

require_relative '../libs/local_env'

module Services
  class Documents
    include XA::Rules::Parse

    LOCAL_ENV = LocalEnv.new(
      'MONGO', {
        url: { type: :string, default: 'mongodb://127.0.0.1:27017/xadf' },
      })
    
    def initialize()
      url = LOCAL_ENV.get(:url)
      
      puts "> connecting to Mongo (url=#{url})"
      @cl = Mongo::Client.new(url)
      puts "< connected"
      
      @subscribers = {
        'meta'   => [],
        'rules'  => [],
        'tables' => [],
      }
    end

    def subscribe(name, fn)
      @subscribers[name] << fn
    end
    
    def store_packages(origin_url, pkgs)
      ids = { }

      pkgs.each do |pkg_name, pkg|
        pkg_info = pkg.fetch('package', {})
        store_package_version(pkg_name, pkg_info) do
          rule_ids = store_thing(origin_url, pkg_name, pkg, 'rules') do |content|
            parse(content)
          end
          table_ids = store_thing(origin_url, pkg_name, pkg, 'tables') do |content|
            { table: CSV.parse(content) }
          end

          { rules: rule_ids, tables: table_ids }
        end
      end
    end

    def remove_revision(url, revision)
      doc = @cl['packages'].find(url: url).first
      if doc
        # [0] => the version we're removing
        # [1] => everyone else
        revisions = doc['revisions'].partition { |rev| rev['version'] == revision }

        # collect all the ids which will remain into Set for faster matching
        ids = revisions[1].inject({ 'rules' => Set.new, 'tables' => Set.new }) do |o, rev|
          o.merge(rev['contents'].inject({}) do |cho, (k, v)|
                    cho.merge(k => o[k].merge(v))
                  end)
        end

        # collect all the dangling ids in the revision we're removing and delete them at once
        revisions[0].first['contents'].inject({}) do |o, (k, v)|
          o.merge(k => v.select { |id| !ids[k].include?(id) })
        end.each do |k, ids|
          puts "# removing matching objects (k=#{k}; ids=#{ids})"
          @cl[k].delete_many('public_id' => { '$in' => ids })
        end

        @cl['packages'].update_one({ '_id' => doc['_id'] }, '$pull' => { 'revisions' => { version: revision } })
        
      else
        puts "? documents: failed to locate document to revise (url=#{url})"
      end
    end

    def find_meta(id, &bl)
      find_one('meta', id, &bl)
    end
    
    def find_rule(id, &bl)
      find_one('rules', id, &bl)
    end
    
    def all(cn)
      @cl[cn].find({}).map { |o| { 'id' => o['public_id'] } }
    end
    
    def one(cn, id)
      doc = find_one(cn, id)
      doc ? doc.except('_id', 'public_id').merge('id' => doc['public_id']) : nil
    end

    def remove(cn, id)
      @removals ||= {
        'rules' => lambda { |id| remove_content('rules', id) },
        'tables' => lambda { |id| remove_content('tables', id) },
        'packages' => lambda { |id| remove_package(id) },
      }

      fn = @removals.fetch(cn, nil)
      fn.call(id)
    end
    
    private

    def remove_content(cn, id)
      packages = @cl['packages'].find(revisions: {
                           '$elemMatch' => {
                             'contents.rules' => { '$in' => ['94facf5dfd77b6a5ff1c23d40f35e26a2bd82038'] }
                           }
                           })
      packages.each do |doc|
        revisions = doc['revisions'].map do |rev|
          rev.merge('contents' => rev['contents'].merge(cn => rev['contents'].fetch(cn, []) - [id]))
        end
        doc.merge('revisions' => revisions)
        @cl['packages'].update_one({ '_id' => doc['_id'] }, { '$set' => { 'revisions' => revisions } })
      end
      
      @cl[cn].delete_one(public_id: id)
      @cl['meta'].delete_one(public_id: id)
    end

    def remove_package(id)
      find_one('packages', id) do |doc|
        ids = doc.fetch('revisions', []).inject({ 'rules' => Set.new, 'tables' => Set.new }) do |ids, rev|
          contents = rev.fetch('contents', {})
          ids.merge(
            'rules' => ids['rules'] + contents.fetch('rules', []),
            'tables' => ids['tables'] + contents.fetch('tables', []),
          )
        end

        ids.each do |cn, ids|
          ids.each do |id|
            @cl[cn].delete_one(public_id: id)
            @cl['meta'].delete_one(public_id: id)
          end
        end
      end

      @cl['packages'].delete_one('public_id' => id)
    end
    
    def find_one(cn, id, &bl)
      doc = @cl[cn].find(public_id: id).first
      bl.call(doc) if bl && doc
      doc
    end

    def store_package_version(name, pkg_info)
      doc = @cl['packages'].find({ name: name }).first
      contents = yield
      if !doc
        puts "# creating new package (name=#{name}; version=#{pkg_info['revision']}; url=#{pkg_info['url']})"
        @cl['packages'].insert_one({ public_id: UUID.generate, name: name, url: pkg_info['url'], revisions: [{ version: pkg_info['revision'], contents: contents }] })
      elsif doc && !doc['revisions'].find { |rev| rev['version'] == pkg_info['revision'] }
        puts "# updating package (name=#{name}; version=#{pkg_info['revision']})"
        @cl['packages'].update_one({ '_id' => doc['_id'] }, '$push' => { 'revisions' => { version: pkg_info['revision'], contents: contents } })
      else
        puts "? package version already exists, nothing to do (name=#{name}; version=#{revision})"
      end
    end
    
    def store_thing(origin_url, pkg_name, pkg, pkg_section, &bl)
      @things ||= {
        'rules'   => { 'type' => 'rule',    'prefix' => 'R', 'collection' => 'rules' },
        'tables'  => { 'type' => 'table',   'prefix' => 'T', 'collection' => 'tables' },
      }
      ids = pkg.fetch(pkg_section, {}).map do |thing_name, thing|
        id = build_id(@things[pkg_section]['prefix'], pkg_name, thing_name, thing['version'])
        if !exists?(id)
          store_document('meta', id, thing.merge(name: thing_name, package: pkg_name, origin_url: origin_url, type: @things[pkg_section]['type']))
          content = thing.fetch('content', '')
          store_document(@things[pkg_section]['collection'], id, bl ? bl.call(content) : content)
        else
          p "# exists (id=#{id})"
        end
        
        id
      end
    end

    def exists?(id)
      @cl['meta'].count(public_id: id) > 0
    end
    
    def store_document(cn, id, doc)
      @cl[cn].insert_one(doc.merge(public_id: id))
      fns = @subscribers.fetch(cn, [])
      fns.each { |fn| fn.call(id) }
    end
    
    def build_id(prefix, pkg_name, thing_name, thing_ver)
      Digest::SHA1.hexdigest("#{prefix}(#{pkg_name}:#{thing_name}:#{thing_ver})")
    end
  end
end
