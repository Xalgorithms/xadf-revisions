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
require 'radish/documents/core'

require_relative '../../jobs/add_table'
require_relative '../../lib/ids'
require_relative './add_xalgo_checks'

describe Jobs::AddTable do
  include Ids
  include Specs::Jobs::AddXalgoChecks
  include Radish::Documents::Core
  include Radish::Randomness

  it "should always store the document, meta and effective (on any branch)" do
    rand_array { Faker::Lorem.word }.each do |branch|
      verify_storage(Jobs::AddTable, 'table', nil, nil, branch: branch)
    end
  end
  
  it "should always store the document, meta and effective (on master)" do
    verify_storage(Jobs::AddTable, 'table', nil, nil, branch: 'master')
  end
  
  it "should not store the document, meta and effective if the rule exists (on production)" do
    verify_storage(Jobs::AddTable, 'table', nil, nil, branch: 'production', should_store_rule: false)
  end
  
  it "should store the document, meta and effective if the rule does not exist (on production)" do
    verify_storage(Jobs::AddTable, 'table', nil, nil, branch: 'production', should_store_rule: true)
  end
end
