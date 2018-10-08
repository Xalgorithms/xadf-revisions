# Copyright (C) 2018 Don Kelly <karfai@gmail.com>
# Copyright (C) 2018 Hayk Pilosyan <hayk.pilos@gmail.com>

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

require_relative '../../jobs/remove_rule'
require_relative '../../jobs/remove_meta'
require_relative '../../jobs/remove_effective'
require_relative '../../jobs/remove_applicable'
require_relative '../../jobs/remove_stored_rule'
require_relative '../../jobs/storage'
require_relative '../../lib/ids'

describe Jobs::RemoveRule do
  include Radish::Randomness
  include Ids

  it 'should trigger removal jobs' do
    rand_times do
      origin = Faker::Internet.url
      branch = Faker::Lorem.word
      ns = Faker::Lorem.word
      name = Faker::Lorem.word
      version = Faker::App.semantic_version

      rule_id = make_id('rule', 'ns' => ns, 'name' => name, 'version' => version)

      expect(Jobs::RemoveMeta).to receive(:perform_async).with(origin: origin, branch: branch, rule_id: rule_id)
      expect(Jobs::RemoveEffective).to receive(:perform_async).with(rule_id: rule_id)
      expect(Jobs::RemoveApplicable).to receive(:perform_async).with(rule_id: rule_id)
      expect(Jobs::RemoveStoredRule).to receive(:perform_async).with(rule_id: rule_id)

      job = Jobs::RemoveRule.new
      args = {
        'origin'  => origin,
        'branch'  => branch,
        'ns'      => ns,
        'name'    => name,
        'version' => version,
      }

      job.perform(rand_document.merge(args))
    end
  end

  it 'should do nothing if the args are not specified' do
    keys = [:origin, :branch, :ns, :name, :version]
    rand_times do
      expect(Jobs::RemoveMeta).to_not receive(:perform_async)
      expect(Jobs::RemoveEffective).to_not receive(:perform_async)
      expect(Jobs::RemoveApplicable).to_not receive(:perform_async)
      expect(Jobs::RemoveStoredRule).to_not receive(:perform_async)

      job = Jobs::RemoveRule.new
      job.perform(rand_document.merge(keys.sample(2).inject({}) { |o, k| o.merge(k => k) }))
    end
  end
end
