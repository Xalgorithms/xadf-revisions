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
require 'active_support/core_ext/integer/time'
require 'countries'
require 'faker'
require 'tzinfo'

require_relative '../../jobs/add_xalgo'
require_relative '../../jobs/storage'
require_relative './add_xalgo_checks'

describe Jobs::AddXalgo do
  include Radish::Randomness
  include Specs::Jobs::AddXalgoChecks
  
  it "should store the document, meta and effective" do
    expects = build_expects

    expects.each do |ex|
      doc_type = ['rule', 'table'].sample
      args = build_args_from_expectation(ex)
      parsed = build_parsed_from_expectation(ex)

      job = Jobs::AddXalgo.new(doc_type)
      
      expect(job).to receive("parse_#{doc_type}").with(ex[:data]).and_return(parsed)
      expect(Jobs::Storage.instance.docs).to receive(:store_rule).with(
                                               doc_type,
                                               {
                                                 'ns' => ex[:args][:ns],
                                                 'name' => ex[:args][:name],
                                                 'origin' => ex[:args][:origin],
                                               },
                                               parsed).and_return(ex[:public_id])
      
      expect(Jobs::Storage.instance.tables).to receive(:store_meta).with(build_expected_meta(ex))

      expect(Jobs::Storage.instance.tables).to receive(:store_effectives).with(build_expected_effectives(ex))
      expect(job).to receive(:perform_additional).with(build_args_from_expectation(ex), parsed, ex[:public_id])

      job.perform(ex[:args].with_indifferent_access.merge('data' => ex[:data]))
    end
  end
end
