require 'multi_json'
require 'rugged'

module Services
  class GitHub
    def process(url)
      path = Pathname.new(URI.parse(url).path)
      dn = path.basename('.git').to_s
      repo = Rugged::Repository.clone_at(url, dn, bare: true)

      versions = find_versions_using_tags(repo)

      versions.each do |ver|
        packages = {}
        ver.tag.target.tree.each_tree do |tr|
          pkg = process_package(repo, tr).merge('package' => { 'name' => tr[:name], 'revision' => ver.rev })
          packages = packages.merge(tr[:name] => pkg)
        end

        yield(packages)
      end

      FileUtils.rm_rf(dn)

      { versions: versions.map(&:rev) }
    end

    def event(name, o)
      @events ||= {
        'create' => method(:create),
        'delete' => method(:delete),
        'push'   => method(:push),
      }
      fn = @events.fetch(name, lambda { |_| puts "? unknown event #{name}" })
      fn.call(o)
    end

    private

    def create(o)
      puts '# create event'
    end

    def delete(o)
      puts '# delete event'
    end

    def push(o)
      puts '# push event'
    end

    def process_package(repo, tr)
      interpret_contents(repo, build_package_contents(repo, tr))
    end

    def find_versions_using_tags(repo)
      versions = []
      repo.tags.each_name do |n|
        m = /^v([0-9]+\.[0-9]+\.[0-9]+)$/.match(n)
        versions << OpenStruct.new({ tag: repo.tags[n], rev: m[1] }) if m
      end
      versions
    end

    def build_package_contents(repo, tr)
      repo.lookup(tr[:oid]).inject({}) do |c, o|
        path = Pathname.new(o[:name])
        ext = path.extname

        if '.package' == ext
          c.merge('package' => o[:oid])
        elsif '.rule' == ext
          c.merge('rules' => c.fetch('rules', {}).merge(path.basename('.rule').to_s => { id: o[:oid], path: File.join(tr[:name], o[:name]) }))
        elsif '.csv' == ext
          c.merge('tables' => c.fetch('tables', {}).merge(path.basename('.csv').to_s => { id: o[:oid], path: File.join(tr[:name], o[:name]) }))
        else
          c
        end
      end
    end

    def interpret_contents(repo, contents)
      pkg = MultiJson.decode(repo.read(contents['package']).data)

      ['rules', 'tables'].each do |section|
        pkg[section].keys.each do |k|
          it = contents[section][k]
          pkg[section][k]['content'] = repo.read(it[:id]).data
          co = lookup_latest_commit(repo, it[:path])
          pkg[section][k]['roles']['committer'] = { 'name' => co.committer[:name], 'email' => co.committer[:email] }
        end
      end

      pkg
    end
    
    def lookup_latest_commit(repo, path)
      bl = Rugged::Blame.new(repo, path)
      repo.lookup(bl[bl.count - 1][:final_commit_id])
    end
  end
end
