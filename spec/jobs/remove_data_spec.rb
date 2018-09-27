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

require_relative '../../jobs/remove_data'
require_relative '../../jobs/storage'

describe Jobs::RemoveRule do
  include Radish::Randomness

  it 'should trigger removal jobs' do
    rand_times do
      origin = Faker::Internet.url
      branch = Faker::Lorem.word

      job = Jobs::RemoveData.new
      args = {
        'origin' => origin,
        'branch' => branch,
      }

      expect(Jobs::Storage.instance.docs).to receive(:remove_table_data_by_origin_branch).with(origin, branch)
      
      job.perform(rand_document.merge(args))
    end
  end

  it 'should do nothing if the args are not specified' do
    keys = [:origin, :branch]
    rand_times do
      expect(Jobs::Storage.instance.docs).to_not receive(:remove_table_data_by_origin_branch)

      job = Jobs::RemoveData.new
      job.perform(rand_document.merge(keys.sample(1).inject({}) { |o, k| o.merge(k => k) }))
    end
  end
end
