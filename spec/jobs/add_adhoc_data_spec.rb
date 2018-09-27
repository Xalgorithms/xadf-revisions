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
require 'multi_json'

require_relative '../../jobs/add_adhoc_data'
require_relative '../../jobs/storage'
require_relative './add_xalgo_checks'

describe Jobs::AddAdhocData do
  include Radish::Randomness

  it 'should store JSON from the arguments' do
    rand_times do
      data = rand_document
      args = rand_document

      ex = {
        'origin' => 'origin:adhoc',
        'branch' => 'branch:adhoc',
        'data' => data,
      }
      
      expect(Jobs::Storage.instance.docs).to receive(:store_table_data).with(args.merge(ex))
      
      job = Jobs::AddAdhocData.new
      job.perform(args.merge('data' => MultiJson.encode(data)))
    end
  end

  it 'should do nothing if data is not JSON' do
    rand_times do
      args = rand_document

      expect(Jobs::Storage.instance.docs).to_not receive(:store_table_data)
      
      job = Jobs::AddAdhocData.new
      job.perform(args.merge('data' => Faker::Lorem.paragraph))
    end
  end
end
