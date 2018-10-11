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
require 'active_support/core_ext/hash'
require 'faker'

require_relative '../../jobs/add_rule'
require_relative '../../jobs/add_table'
require_relative '../../jobs/remove_rule'
require_relative '../../jobs/remove_table'
require_relative '../../jobs/remove_effective'
require_relative '../../jobs/remove_applicable'
require_relative '../../jobs/remove_meta'
require_relative '../../jobs/remove_stored_rules'
require_relative '../../jobs/update_repo'
require_relative '../../jobs/storage'
require_relative '../../lib/github'

describe Jobs::UpdateRepo do
  include Radish::Randomness

  let(:update_jobs) do
    {
      'rule'  => Jobs::AddRule,
      'table' => Jobs::AddTable,
    }
  end

  let(:remove_jobs) do
    {
      'rule'  => Jobs::RemoveRule,
      'table' => Jobs::RemoveTable,
    }
  end

  let(:ops) do
    [:added, :modified, :removed]
  end
  
  it 'should update content when a branch is updated' do
    rand_times do
      url = Faker::Internet.url
      branch = Faker::Lorem.word

      changes = ops.inject({}) do |o, k|
        items = rand_array do
          {
            ns: Faker::Lorem.word,
            name: Faker::Lorem.word,
            type: update_jobs.keys.sample,
          }
        end
        o.merge(k => items)
      end

      github_items = changes.inject([]) do |a, (op, file_changes)|
        a + file_changes.map do |file_change|
          file_change.merge(
            data: Faker::Lorem.paragraph,
            origin: url,
            branch: branch,
            op: op,
          )
        end
      end

      prev_commit_id = Faker::Number.hexadecimal(40)
      commit_id = Faker::Number.hexadecimal(40)

      requested_changes = changes.inject({}) do |o, (op, file_changes) |
        o.merge(op.to_s => file_changes.map do |file_change|
                  File.join(file_change[:ns], "#{file_change[:name]}.#{file_change[:type]}")
                end)
      end.merge(
        'previous_commit_id' => prev_commit_id,
        'commit_id'          => commit_id,
      )

      expect(Jobs::Storage.instance.tables).to receive(:if_has_repository).with(url).and_yield

      gh = double('fake/github')
      expect(GitHub).to receive(:new).and_return(gh)
      expect(gh).to receive(:get_changed_files).with(url, branch, requested_changes).and_return(github_items)

      parts = github_items.partition do |it|
        it[:op] == :removed
      end

      parts.first.each do |it|
        expect(remove_jobs[it[:type]]).to receive(:perform_async).with(it)
      end

      parts.last.each do |it|
        expect(update_jobs[it[:type]]).to receive(:perform_async).with(it)
      end
      
      job = Jobs::UpdateRepo.new
      job_args = {
        'url'     => url,
        'branch'  => branch,
        'what'    => 'branch_updated',
        'changes' => [requested_changes],
      }
      job.perform(job_args)
    end
  end

  def verify_unknown(what)
    url = Faker::Internet.url

    expect(Jobs::Storage.instance.tables).to receive(:if_has_repository).with(url)
    expect(GitHub).to_not receive(:new)
    
    job_args = rand_document.merge('url' => url, 'what' => what)
    job = Jobs::UpdateRepo.new
    job.perform(job_args)
  end
  
  it 'should do nothing when a branch is updated in a repo that is not tracked' do
    verify_unknown('branch_updated')
  end

  it 'should purge content when a branch is removed' do
    rand_times do
      url = Faker::Internet.url
      branch = Faker::Lorem.word
      rule_ids = rand_array { Faker::Number.hexadecimal(40) }

      expect(Jobs::Storage.instance.tables).to receive(:if_has_repository).with(url).and_yield
      receive_lookup = receive(:lookup_rules_in_repo).with(url, branch)
      rule_ids.each do |id|
        receive_lookup = receive_lookup.and_yield(id)
      end
      expect(Jobs::Storage.instance.tables).to receive_lookup

      rule_ids.each do |id|
        expect(Jobs::RemoveMeta).to receive(:perform_async).with(origin: url, branch: branch, rule_id: id)
        expect(Jobs::RemoveEffective).to receive(:perform_async).with(rule_id: id)
        expect(Jobs::RemoveApplicable).to receive(:perform_async).with(rule_id: id)
      end

      expect(Jobs::RemoveStoredRules).to receive(:perform_async).with(origin: url, branch: branch)

      job = Jobs::UpdateRepo.new
      job_args = rand_document.merge('url' => url, 'branch' => branch, 'what' => 'branch_removed')
      job.perform(job_args)
    end
  end

  it 'should do nothing when a branch is removed in a repo that is not tracked' do
    verify_unknown('branch_removed')
  end

  it 'should add content when a branch is added' do
    rand_times do
      url = Faker::Internet.url
      branch = Faker::Lorem.word

      github_items = rand_array do
        rand_document.merge(type: update_jobs.keys.sample)
      end

      gh = double('fake/github')
      expect(GitHub).to receive(:new).and_return(gh)
      expect(gh).to receive(:get).with(url, branch).and_return(github_items)
      
      expect(Jobs::Storage.instance.tables).to receive(:if_has_repository).with(url).and_yield

      github_items.each do |it|
        expect(update_jobs[it[:type]]).to receive(:perform_async).with(it)
      end
      
      job = Jobs::UpdateRepo.new
      job_args = rand_document.merge('url' => url, 'branch' => branch, 'what' => 'branch_created')
      job.perform(job_args)
    end
  end

  it 'should do nothing when a branch is created in a repo that is not tracked' do
    verify_unknown('branch_created')
  end
end

