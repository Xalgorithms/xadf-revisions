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

module Specs
  module Jobs
    module AddXalgoChecks
      include Radish::Randomness
  
      def build_expects
        rand_array do
          {
            public_id: SecureRandom.hex,
            args: {
              ns: Faker::Lorem.word,
              name: Faker::Lorem.word,
              origin: Faker::Internet.url,
              branch: ['master', 'production'].sample,
            },
            effectives: rand_array(5) do
              c = ISO3166::Country.all.sample(10).select { |c| c.subdivisions.any? }.first
              {
                country: c.alpha2,
                timezone: TZInfo::Timezone.all_identifiers.sample,
                starts: "#{Faker::Time.between(1.year.ago, Date.today, :all)}",
                ends: "#{Faker::Time.between(Date.today, 1.year.from_now, :all)}",
                keys: rand_array { Faker::Lorem.word },
                regions: c.subdivisions.keys.sample(5),
              }
            end,
            meta: {
              version: "#{Faker::Number.number(1)}.#{Faker::Number.number(1)}.#{Faker::Number.number(2)}",
              runtime: "#{Faker::Number.number(1)}.#{Faker::Number.number(1)}.#{Faker::Number.number(2)}",
              criticality: Faker::Lorem.word,
            },
            data: Faker::Lorem.paragraph(2),
          }
        end
      end

      def build_args_from_expectation(ex)
        ex[:args].merge(data: ex[:data]).with_indifferent_access
      end

      def build_parsed_from_expectation(ex)
        {
          'effective' => ex[:effectives].map do |eff|
            juris = eff[:regions].map { |region| "#{eff[:country]}-#{region}" }
            eff.except(:regions).merge(jurisdictions: juris).with_indifferent_access
          end,
          'meta' => ex[:meta].with_indifferent_access,
        }
      end

      def build_expected_effectives(ex)
        ex_effs = ex[:effectives].inject([]) do |all_a, eff|
          all_a + eff[:regions].inject([]) do |reg_a, region|
            reg_a + eff[:keys].map do |k|
              eff.except(:regions, :keys).merge(region: region, key: k, rule_id: ex[:public_id])
            end
          end
        end
      end

      def build_expected_meta(ex)
        ex[:meta].merge(ex[:args]).merge(rule_id: ex[:public_id])
      end
    end
  end
end
