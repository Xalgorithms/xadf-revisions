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
  
  def build_fake_repo(fake_branches)
    url = 'https://github.com/Xalgorithms/testing-rules.git'
    path = 'testing-rules'

    repo = double('Rugged::Repository')
    branches = double('branches')

    fake_branches.each do |n, br_contents|
      expect(branches).to receive('[]').with(n.to_s).and_return(build_fake_branch(repo, n, br_contents))
    end
    expect(repo).to receive(:branches).twice.and_return(branches)
    expect(Rugged::Repository).to receive(:clone_at).with(url, path, bare: true).and_return(repo)

    { repo: repo, url: url, path: path }
  end
  
  it 'should yield nothing if branches do not exist' do
    repo = build_fake_repo(master: nil, production: nil)

    gh = GitHub.new
    ac = gh.get(repo[:url])
    expect(ac).to eql(nil)
  end

  it 'should enumerate top-level directories as namespaces and yield the valid contents' do
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

    contents = { master: master_contents, production: prod_contents }
    
    repo = build_fake_repo(contents)
    ex = contents.inject([]) do |a, (br, br_contents)|
      a + br_contents.fetch(:whitelist, br_contents[:nses].keys).inject([]) do |files_a, ns|
        files_a + br_contents[:nses][ns].map do |fn|
          path = Pathname.new(fn)
          ext = path.extname
          {
            ns: ns,
            name: path.basename(path.extname).to_s,
            type: path.extname[1..-1],
            origin: repo[:url],
            branch: br.to_s,
            data: "contents of #{fn}",
          }
        end
      end
    end

    expect(FileUtils).to receive(:rm_rf).with(repo[:path])
    
    gh = GitHub.new
    ac = gh.get(repo[:url])
    expect(ac).to eql(ex)
  end
end
