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

require_relative '../../jobs/remove_effective'
require_relative '../../jobs/storage'

describe Jobs::RemoveEffective do
  include Radish::Randomness

  it 'should trigger removals on document storage' do
    rand_times do
      rule_id = Faker::Number.hexadecimal(40)

      expect(Jobs::Storage.instance.tables).to receive(:unless_rule_in_use).with(rule_id).and_yield
      expect(Jobs::Storage.instance.tables).to receive(:remove_effective).with(rule_id)

      job = Jobs::RemoveEffective.new
      job.perform(rand_document.merge('rule_id' => rule_id))
    end
  end

  it 'should do nothing if the rule_id is still in use' do
    rand_times do
      rule_id = Faker::Number.hexadecimal(40)

      expect(Jobs::Storage.instance.tables).to receive(:unless_rule_in_use).with(rule_id)
      expect(Jobs::Storage.instance.tables).to_not receive(:remove_applicable)

      job = Jobs::RemoveEffective.new
      job.perform(rand_document.merge('rule_id' => rule_id))
    end
  end
  
  it 'should do nothing if the rule_id is not specified' do
    rand_times do
      expect(Jobs::Storage.instance.tables).to_not receive(:remove_effective)

      job = Jobs::RemoveEffective.new
      job.perform(rand_document)
    end
  end
end
