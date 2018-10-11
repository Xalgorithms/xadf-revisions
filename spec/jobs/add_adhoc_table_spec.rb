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

require_relative '../../jobs/add_adhoc_table'
require_relative '../../lib/ids'
require_relative './add_xalgo_checks'

describe Jobs::AddTable do
  include Specs::Jobs::AddXalgoChecks
  include Radish::Randomness

  it "should always store the document, meta, applicable and effective" do
    rand_times do
      props = {
        origin: 'origin:adhoc',
        branch: 'branch:adhoc',
        expected_data: rand_array { rand_document }
      }
      verify_storage(Jobs::AddAdhocTable, 'table', nil, nil, props)
    end
  end
end
