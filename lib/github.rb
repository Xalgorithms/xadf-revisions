# Copyright (C) 2018 Don Kelly <karfai@gmail.com>
# Copyright (C) 2018 Hayk Pilosyan <hayk.pilos@gmail.com>

# This file is part of Interlibr, a functional component of an
# Internet of Rules (IoR).

# ACKNOWLEDGEMENTS
# Funds: Xalgorithms Foundation
# Collaborators: Don Kelly, Joseph Potvin and Bill Olders.

# This program is free software: you can redistribute it and/or
# modify it under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public
# License along with this program. If not, see
# <http://www.gnu.org/licenses/>.
require 'multi_json'
require 'rugged'

class GitHub
  def get(url, branch=nil)
    with_repo(url) do |repo|
      branch_names = branch ? [branch] : ['master', 'production']
      rv = enumerate_namespaces_by_branches(repo, branch_names).inject([]) do |a, ns|
        props = { origin: url, branch: ns[:branch].name, ns: ns[:name] }
        a + ns[:tree].map do |ref|
          props.merge(populate_file_content(repo, ref))
        end
      end
      
      rv.any? ? rv : nil
    end
  end

  def get_changed_files(url, branch_name, prev_commit_id, commit_id, changes)
    with_repo(url) do |repo|
      changes.inject([]) do |a, (change, fns)|
        tree_id = change == :removed ? prev_commit_id : commit_id
        tr = repo.lookup(tree_id).tree

        props = {
          origin: url,
          branch: branch_name,
          op: change,
        }
        
        a + fns.map do |fn|
          ref = tr.path(fn)
          pn = Pathname.new(fn)
          this_props = {
            ns: pn.dirname.to_s
          }.merge(props)
          populate_file_content(repo, ref).merge(this_props)
        end
      end
    end
  end
  
  # def event(name, o, &bl)
  #   @events ||= {
  #     'create' => method(:create),
  #     'delete' => method(:delete),
  #     'push'   => method(:push),
  #   }
  #   fn = @events.fetch(name, lambda { |_| puts "? unknown event #{name}" })
  #   fn.call(o, &bl)
  # end

  private
  
  def with_repo(url)
    puts "> fetching (url=#{url})"
    
    path = Pathname.new(URI.parse(url).path)
    dn = path.basename('.git').to_s
    rv = yield(Rugged::Repository.clone_at(url, dn, bare: true))

    FileUtils.rm_rf(dn)

    rv
  end

  def populate_file_content(repo, ref)
    path = Pathname.new(ref[:name])
    {
      name: path.basename(path.extname).to_s,
      type: path.extname[1..-1],
      data: repo.read(ref[:oid]).data
    }
  end
  
  def enumerate_namespaces_by_branches(repo, branch_names)
    branch_names.inject([]) do |a, bn|
      br = repo.branches[bn]
      br ? a + [br] : a
    end.inject([]) do |a, br|
      a + get_namespaces_on_branch(repo, br).map do |ns|
        ref = br.target.tree.path(ns)
        { name: ns, tree: repo.lookup(ref[:oid]), branch: br }
      end
    end
  end

  def get_namespaces_on_branch(repo, br)
    begin
      o = br.target.tree.path('namespaces.txt')
      repo.read(o[:oid]).data.split("\n")
    rescue Rugged::TreeError => e
      nses = []
      br.target.tree.each_tree do |tr|
        nses << tr[:name]
      end
      
      nses
    end    
  end

  # def create(o, &bl)
  #   @create_types ||= {
  #     'tag' => method(:create_tag),
  #   }

  #   puts '# create event'
  #   t = o.fetch('ref_type', nil)
  #   if t
  #     fn = @create_types.fetch(t, lambda { |_| puts "? create: unknown type (type=#{t}" })
  #     fn.call(o, &bl)
  #   else
  #     puts '! create: type not specified in event'
  #   end
  # end

  # def create_tag(o, &bl)
  #   ref = o.fetch('ref', nil)
  #   url = o.fetch('repository', {}).fetch('clone_url', nil)
  #   if ref && url
  #     puts "# created tag, pulling version (tag=#{ref}; url=#{url})"
  #     pull_revisions(url, lambda { |repo| find_version_for_tag(repo, ref) }) do |packages|
  #       bl.call(action: :update, url: url, packages: packages)
  #     end
  #   else
  #     {}
  #   end
  # end

  # def delete(o, &bl)
  #   @delete_types ||= {
  #     'tag' => method(:delete_tag),
  #   }

  #   puts '# delete event'
  #   t = o.fetch('ref_type', nil)
  #   if t
  #     fn = @delete_types.fetch(t, lambda { |_| puts "? delete: unknown type (type=#{t}" })
  #     fn.call(o, &bl)
  #   else
  #     puts '! delete: type not specified in event'
  #   end      
  # end

  # def delete_tag(o, &bl)
  #   ref = o.fetch('ref', nil)
  #   url = o.fetch('repository', {}).fetch('clone_url', nil)
  #   rev = match_tag(ref)
  #   if rev && url
  #     puts "# deleted tag, informing caller (rev=#{rev}; url=#{url})"
  #     bl.call(action: :delete, url: url, revision: rev)

  #     { versions: [rev] }
  #   else
  #     {}
  #   end
  # end

  # def push(o, &bl)
  #   puts '# push event'
  # end

  # def process_package(repo, tr)
  #   interpret_contents(repo, build_package_contents(repo, tr))
  # end

  # def match_tag(n)
  #   m = /^v([0-9]+\.[0-9]+\.[0-9]+)$/.match(n)
  #   m ? m[1] : nil
  # end
  
  # def find_versions_using_tags(repo)
  #   versions = []
  #   repo.tags.each_name do |n|
  #     rev = match_tag(n)
  #     versions << OpenStruct.new({ tag: repo.tags[n], rev: rev }) if rev
  #   end
  #   versions
  # end

  # def find_version_for_tag(repo, ref)
  #   tag = repo.tags[ref]
  #   rev = match_tag(ref)
  #   (rev && tag) ? [OpenStruct.new({ tag: tag, rev: rev })] : []
  # end

  # def build_package_contents(repo, tr)
  #   repo.lookup(tr[:oid]).inject({}) do |c, o|
  #     path = Pathname.new(o[:name])
  #     ext = path.extname

  #     if '.package' == ext
  #       c.merge('package' => o[:oid])
  #     elsif '.rule' == ext
  #       c.merge('rules' => c.fetch('rules', {}).merge(path.basename('.rule').to_s => { id: o[:oid], path: File.join(tr[:name], o[:name]) }))
  #     elsif '.csv' == ext
  #       c.merge('tables' => c.fetch('tables', {}).merge(path.basename('.csv').to_s => { id: o[:oid], path: File.join(tr[:name], o[:name]) }))
  #     else
  #       c
  #     end
  #   end
  # end

  # def interpret_contents(repo, contents)
  #   pkg = MultiJson.decode(repo.read(contents['package']).data)

  #   ['rules', 'tables'].each do |section|
  #     pkg[section].keys.each do |k|
  #       it = contents[section][k]
  #       pkg[section][k]['content'] = repo.read(it[:id]).data
  #       co = lookup_latest_commit(repo, it[:path])
  #       pkg[section][k]['roles']['committer'] = { 'name' => co.committer[:name], 'email' => co.committer[:email] }
  #     end
  #   end

  #   pkg
  # end
  
  # def lookup_latest_commit(repo, path)
  #   bl = Rugged::Blame.new(repo, path)
  #   repo.lookup(bl[bl.count - 1][:final_commit_id])
  # end
end
