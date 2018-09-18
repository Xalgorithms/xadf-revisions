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
require 'faker'

require_relative '../../lib/github'

describe GitHub do
  include Radish::Randomness

  def build_fake_branch(repo, name, contents)
    if contents
      br = double("Fake branch: #{name}")
      target = double("Fake target: #{name}")
      tree = double("Fake tree: #{name}")

      expect(br).to receive(:name).at_least(:once).and_return(name.to_s)
      expect(br).to receive(:target).at_least(:once).and_return(target)
      expect(target).to receive(:tree).at_least(:once).and_return(tree)

      if contents.key?(:whitelist)
        nses = contents[:whitelist]
        oid = Faker::Number.hexadecimal(40)
        file_content = double("namespaces.txt: #{oid}")

        expect(tree).to receive(:path).with('namespaces.txt').and_return(oid: oid)
        expect(file_content).to receive(:data).and_return(nses.join("\n"))
        expect(repo).to receive(:read).with(oid).and_return(file_content)
      else
        nses = contents[:nses].keys

        expect(tree).to receive(:path).with('namespaces.txt').and_raise(Rugged::TreeError)

        receive_and_yield_nses = receive(:each_tree)
        nses.each do |ns|
          recv = receive_and_yield_nses.and_yield(name: ns)
        end
        expect(tree).to receive_and_yield_nses
      end

      nses.each do |ns|
        ref = {
          oid: Faker::Number.hexadecimal(40),
          name: ns,
        }
        file_list = contents[:nses][ns].map do |fn|
          {
            oid: Faker::Number.hexadecimal(40),
            name: fn,
          }
        end
        expect(tree).to receive(:path).with(ns).and_return(ref)
        expect(repo).to receive(:lookup).with(ref[:oid]).and_return(file_list)
        file_list.each do |f_ref|
          content = double("Content: #{f_ref[:oid]} (#{f_ref[:name]})")
          expect(content).to receive(:data).and_return("contents of #{f_ref[:name]}")
          expect(repo).to receive(:read).with(f_ref[:oid]).and_return(content)
        end
      end
      
      br
    end
  end
  
  def build_fake_repo(clones=1)
    url = 'https://github.com/Xalgorithms/testing-rules.git'
    path = 'testing-rules'

    repo = double('Rugged::Repository')
    yield(repo)
    
    expect(Rugged::Repository).to receive(:clone_at).exactly(clones).times.with(url, path, bare: true).and_return(repo)

    { repo: repo, url: url, path: path }
  end

  def build_fake_repo_with_branches(fake_branches, clones=1)
    build_fake_repo(clones) do |fake_repo|
      branches = double('branches')
      
      fake_branches.each do |n, br_contents|
        expect(branches).to receive('[]').with(n.to_s).and_return(build_fake_branch(fake_repo, n, br_contents))
      end
      expect(fake_repo).to receive(:branches).twice.and_return(branches)
    end
  end
  
  it 'should yield nothing if branches do not exist' do
    repo = build_fake_repo_with_branches(master: nil, production: nil)

    gh = GitHub.new
    ac = gh.get(repo[:url])
    expect(ac).to eql(nil)
  end

  def build_contents
    master_contents = {
      nses: {
        'master_ns0' => [
          'a.rule',
          'b.rule',
          '0.table',
          '0.json',
          '1.table',
          '1.json',
        ],
        'master_ns1' => [
          'x.rule',
          'y.rule',
          '0.table',
          '1.json',
        ],
      },
    }
    prod_contents = {
      whitelist: ['prod_ns1'],
      nses: {
        'prod_ns0' => [
          'a.rule',
          'b.rule',
          '0.table',
          '0.json',
          '1.table',
          '1.json',
        ],
        'prod_ns1' => [
          'x.rule',
          'y.rule',
          '0.table',
          '1.json',
        ],
      },
    }

    { master: master_contents, production: prod_contents }    
  end

  def build_expects_from_contents(contents, repo_url)
    contents.inject([]) do |a, (br, br_contents)|
      a + br_contents.fetch(:whitelist, br_contents[:nses].keys).inject([]) do |files_a, ns|
        files_a + br_contents[:nses][ns].map do |fn|
          path = Pathname.new(fn)
          ext = path.extname
          {
            ns: ns,
            name: path.basename(path.extname).to_s,
            type: path.extname[1..-1],
            origin: repo_url,
            branch: br.to_s,
            data: "contents of #{fn}",
          }
        end
      end
    end
  end
  
  it 'should enumerate top-level directories as namespaces and yield the valid contents' do
    contents = build_contents
    
    repo = build_fake_repo_with_branches(contents)
    ex = build_expects_from_contents(contents, repo[:url])

    expect(FileUtils).to receive(:rm_rf).with(repo[:path])
    
    gh = GitHub.new
    ac = gh.get(repo[:url])
    expect(ac).to eql(ex)
  end

  it 'should only enumerate specified branches' do
    contents = build_contents
    
    repo = build_fake_repo_with_branches(contents, 2)
    [:master, :production].each do |branch_name|
      ex = build_expects_from_contents(contents.slice(branch_name), repo[:url])

      expect(FileUtils).to receive(:rm_rf).with(repo[:path])
    
      gh = GitHub.new
      ac = gh.get(repo[:url], branch_name.to_s)
      expect(ac).to eql(ex)
    end
  end

  def build_ref_expects(ex, tree, repo)
    base_name = "#{ex[:name]}.#{ex[:type]}"
    path = File.join(ex[:ns], base_name)
    oid = Faker::Number.hexadecimal(40)
    
    ref = double("fake/ref (#{path})")
    expect(ref).to receive('[]').with(:name).and_return(base_name)
    expect(ref).to receive('[]').with(:oid).and_return(oid)

    obj = double("fake/obj (#{path})")
    expect(obj).to receive(:data).and_return(ex[:data])
    
    expect(tree).to receive(:path).with(path).and_return(ref)
    expect(repo).to receive(:read).with(oid).and_return(obj)
  end
  
  it 'should yield changed files' do
    types = ['json', 'rule', 'table']
             
    rand_array do
      {
        branch: Faker::Lorem.word,
        prev_commit_id: Faker::Number.hexadecimal(40),
        commit_id: Faker::Number.hexadecimal(40),
        changes: [:added, :updated, :removed].inject({}) do |o, op|
          o.merge(op => rand_array(4) do
                    {
                      ns: Faker::Lorem.word,
                      name: Faker::Lorem.word,
                      type: types.sample,
                      data: Faker::Lorem.paragraph,
                    }
                  end)
        end
      }
    end.each do |ex|
      repo = build_fake_repo do |fake_repo|
        curr_tree = double("fake/tree/curr")

        prev_count = ex[:changes][:removed].length
        curr_count = ex[:changes][:added].length + ex[:changes][:updated].length

        prev_tree = double("fake/tree/prev")
        prev_o = double("fake/o/prev")
        expect(prev_o).to receive(:tree).at_least(:once).and_return(prev_tree)

        curr_tree = double("fake/tree/curr")
        curr_o = double("fake/o/curr")
        expect(curr_o).to receive(:tree).at_least(:once).and_return(curr_tree)
        
        expect(fake_repo).to receive(:lookup).with(ex[:prev_commit_id]).at_least(:once).and_return(prev_o)
        expect(fake_repo).to receive(:lookup).with(ex[:commit_id]).at_least(:once).and_return(curr_o)

        changes = ex[:changes]
        changes[:removed].each do |o|
          build_ref_expects(o, prev_tree, fake_repo)
        end

        (changes[:added] + changes[:updated]).each do |o|
          build_ref_expects(o, curr_tree, fake_repo)
        end
      end

      gh = GitHub.new
      changes = ex[:changes].inject({}) do |o, (op, fns)|
        o.merge(op => fns.map do |o|
                  File.join(o[:ns], "#{o[:name]}.#{o[:type]}")
                end)
      end
      
      ac = gh.get_changed_files(
        repo[:url], ex[:branch], ex[:prev_commit_id], ex[:commit_id], changes
      )

      expected = ex[:changes].inject([]) do |a, (op, os)|
        a + os.map do |o|
          o.merge(op: op, branch: ex[:branch], origin: repo[:url])
        end
      end
      expect(ac).to eql(expected)
    end
  end
end
