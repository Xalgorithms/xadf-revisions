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

require_relative '../../jobs/add_rule'
require_relative '../../jobs/storage'
require_relative './add_xalgo_checks'

describe Jobs::AddRule do
  include Specs::Jobs::AddXalgoChecks
  include Radish::Randomness
  
  it "should store the document, meta and effective" do
    expects = build_expects
    
    expects.each do |ex|
      whens = rand_array { Faker::Lorem.word }.inject([]) do |arr, section|
        arr + rand_array do
          {
            section: section,
            key: Faker::Lorem.word,
            op: ['eq', 'gt', 'gte', 'lt', 'lte'].sample,
            val: Faker::Number.number(3).to_s,
            rule_id: ex[:public_id],
          }
        end
      end

      args = build_args_from_expectation(ex)
      parsed = build_parsed_from_expectation(ex).merge('whens' => whens.inject({}) do |o, wh|
                                                         section_whens = o.fetch(wh[:section], [])
                                                         this_wh = {
                                                           expr: {
                                                             left: { key: wh[:key] },
                                                             op: wh[:op],
                                                             right: { value: wh[:val] },
                                                           }
                                                         }
                                                         o.merge(wh[:section] => section_whens + [this_wh])
                                                       end.with_indifferent_access)

      job = Jobs::AddRule.new

      expect(job).to receive("parse_rule").with(ex[:data]).and_return(parsed)
      expect(Jobs::Storage.instance.docs).to receive(:store_rule).with(
                                               'rule',
                                               {
                                                 'ns' => ex[:args][:ns],
                                                 'name' => ex[:args][:name],
                                                 'origin' => ex[:args][:origin],
                                               },
                                               parsed).and_return(ex[:public_id])
      
      expect(Jobs::Storage.instance.tables).to receive(:store_meta).with(build_expected_meta(ex))

      expect(Jobs::Storage.instance.tables).to receive(:store_effectives).with(build_expected_effectives(ex))
      expect(Jobs::Storage.instance.tables).to receive(:store_applicables) do |ac_apps|
        expect(ac_apps.length).to eql(whens.length)
        whens.each { |wh| expect(ac_apps).to include(wh) }
      end


      rv = job.perform(args)
      expect(rv).to eql(false)
    end
  end
end
