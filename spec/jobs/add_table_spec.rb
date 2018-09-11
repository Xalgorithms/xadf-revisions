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
require_relative '../../jobs/storage'
require_relative '../../lib/ids'
require_relative './add_xalgo_checks'

describe Jobs::AddTable do
  include Ids
  include Specs::Jobs::AddXalgoChecks
  include Radish::Documents::Core
  include Radish::Randomness
  
  it "should store the document, meta and effective" do
    expects = build_expects
    
    expects.each do |ex|
      args = build_args_from_expectation(ex)
      parsed = build_parsed_from_expectation(ex)

      job = Jobs::AddTable.new

      ver = get(parsed, 'meta.version')
      meta = build_expected_meta(ex)
      public_id = make_id('table', meta.slice(:ns, :name, :version).with_indifferent_access)
      
      expect(job).to receive("parse_table").with(ex[:data]).and_return(parsed)
      expect(Jobs::Storage.instance.docs).to receive(:store_rule).with(
                                               'table', public_id, meta, parsed
                                             )

      expect(Jobs::Storage.instance.tables).to receive(:store_meta).with(
                                                 meta.merge(rule_id: public_id)
                                               )

      expect(Jobs::Storage.instance.tables).to receive(:store_effectives).with(
                                                 build_expected_effectives(public_id, ex)
                                               )

      rv = job.perform(args)
      expect(rv).to eql(false)
    end
  end
end
