require 'multi_json'
require 'rugged'

module Services
  class GitHub
    def get(url, &bl)
      pull_revisions(url, lambda do |repo|
        find_versions_using_tags(repo)
      end, &bl)
    end

    def event(name, o, &bl)
      @events ||= {
        'create' => method(:create),
        'delete' => method(:delete),
        'push'   => method(:push),
      }
      fn = @events.fetch(name, lambda { |_| puts "? unknown event #{name}" })
      fn.call(o, &bl)
    end

    private

    def pull_revisions(url, versions_fn, &bl)
      path = Pathname.new(URI.parse(url).path)
      dn = path.basename('.git').to_s
      repo = Rugged::Repository.clone_at(url, dn, bare: true)

      versions = versions_fn.call(repo)

      packages = {}
      versions.each do |ver|
        ver.tag.target.tree.each_tree do |tr|
          pkg = process_package(repo, tr).merge('package' => { 'name' => tr[:name], 'revision' => ver.rev, 'url' => url })
          packages = packages.merge(tr[:name] => pkg)
          bl.call(packages)
        end
      end

      FileUtils.rm_rf(dn)

      { versions: versions.map(&:rev) }
    end
    
    def create(o, &bl)
      @create_types ||= {
        'tag' => method(:create_tag),
      }

      puts '# create event'
      t = o.fetch('ref_type', nil)
      if t
        fn = @create_types.fetch(t, lambda { |_| puts "? create: unknown type (type=#{t}" })
        fn.call(o, &bl)
      else
        puts '! create: type not specified in event'
      end
    end

    def create_tag(o, &bl)
      ref = o.fetch('ref', nil)
      url = o.fetch('repository', {}).fetch('clone_url', nil)
      if ref && url
        puts "# created tag, pulling version (tag=#{ref}; url=#{url})"
        pull_revisions(url, lambda { |repo| find_version_for_tag(repo, ref) }) do |packages|
          bl.call(action: :update, url: url, packages: packages)
        end
      else
        {}
      end
    end

    def delete(o, &bl)
      @delete_types ||= {
        'tag' => method(:delete_tag),
      }

      puts '# delete event'
      t = o.fetch('ref_type', nil)
      if t
        fn = @delete_types.fetch(t, lambda { |_| puts "? delete: unknown type (type=#{t}" })
        fn.call(o, &bl)
      else
        puts '! delete: type not specified in event'
      end      
    end

    def delete_tag(o, &bl)
      ref = o.fetch('ref', nil)
      url = o.fetch('repository', {}).fetch('clone_url', nil)
      rev = match_tag(ref)
      if rev && url
        puts "# deleted tag, informing caller (rev=#{rev}; url=#{url})"
        bl.call(action: :delete, url: url, revision: rev)

        { versions: [rev] }
      else
        {}
      end
    end

    def push(o, &bl)
      puts '# push event'
    end

    def process_package(repo, tr)
      interpret_contents(repo, build_package_contents(repo, tr))
    end

    def match_tag(n)
      m = /^v([0-9]+\.[0-9]+\.[0-9]+)$/.match(n)
      m ? m[1] : nil
    end
    
    def find_versions_using_tags(repo)
      versions = []
      repo.tags.each_name do |n|
        rev = match_tag(n)
        versions << OpenStruct.new({ tag: repo.tags[n], rev: rev }) if rev
      end
      versions
    end

    def find_version_for_tag(repo, ref)
      tag = repo.tags[ref]
      rev = match_tag(ref)
      (rev && tag) ? [OpenStruct.new({ tag: tag, rev: rev })] : []
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
