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
end
