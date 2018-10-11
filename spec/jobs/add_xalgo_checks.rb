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

require_relative '../../jobs/storage'
require_relative '../../lib/ids'

module Specs
  module Jobs
    module AddXalgoChecks
      include Ids
      include Radish::Randomness
      
      def verify_storage(job_kl, rule_type, parsed_fn=nil, verify_fn=nil, props={})
        expects = build_expects(props)
        
        expects.each do |ex|
          args = build_args_from_expectation(ex)

          job = job_kl.new

          meta = build_expected_meta(ex)
          public_id = make_id(rule_type, meta.slice(:ns, :name, :version).with_indifferent_access)
          
          parsed = build_parsed_from_expectation(ex)
          parsed = parsed_fn.call(parsed, public_id) if parsed_fn

          expect(job).to receive("parse_#{rule_type}").with(ex[:data]).and_return(parsed)

          has_should_store_rule = props.key?(:should_store_rule)
          should_store_rule = props[:should_store_rule]
          if has_should_store_rule
            receive_unless_has_rule = receive(:unless_has_rule).with(public_id, props[:branch])
            receive_unless_has_rule = receive_unless_has_rule.and_yield if should_store_rule
            
            expect(::Jobs::Storage.instance.tables).to receive_unless_has_rule
          end

          if !has_should_store_rule || should_store_rule
            expect(::Jobs::Storage.instance.docs).to receive(:store_rule).with(
                                                     rule_type, public_id, meta, parsed
                                                   )
            
            expect(::Jobs::Storage.instance.tables).to receive(:store_meta).with(
                                                       meta.merge(rule_id: public_id)
                                                     )

            expect(::Jobs::Storage.instance.tables).to receive(:store_effectives).with(
                                                       build_expected_effectives(public_id, ex)
                                                       )

            verify_fn.call if verify_fn
          end

          if props.key?(:expected_data)
            expect(::Jobs::Storage.instance.docs).to receive(:store_table_data).with(public_id, props[:expected_data])
            args = args.merge('table_data' => {
                                'type' => 'json',
                                'content' => MultiJson.encode(props[:expected_data]),
                              })
          end

          
          rv = job.perform(args)
          expect(rv).to eql(false)
        end
      end
      
      def build_expects(props={})
        # these country codes have discovered bugs in the code that
        # this will test
        interesting_countries = ['NO', 'SG']

        countries = ISO3166::Country.all.sample(Faker::Number.between(1, 10)).select do |c|
          c.subdivisions.any?
        end + interesting_countries.map { |alpha2| ISO3166::Country[alpha2] }
        
        rand_array do
          {
            args: {
              ns: Faker::Lorem.word,
              name: Faker::Lorem.word,
              origin: props.fetch(:origin, Faker::Internet.url),
              branch: props.fetch(:branch, Faker::Lorem.word),
            },
            effectives: countries.map do |c|
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
            eff.except(:regions).merge(jurisdictions: juris)
          end,
          'meta' => ex[:meta],
        }.with_indifferent_access
      end

      def build_expected_effectives(rule_id, ex)
        ex_effs = ex[:effectives].inject([]) do |all_a, eff|
          all_a + eff[:regions].inject([]) do |reg_a, region|
            reg_a + eff[:keys].map do |k|
              eff.except(:regions, :keys).merge(region: region, key: k, rule_id: rule_id)
            end
          end
        end
      end

      def build_expected_meta(ex)
        ex[:meta].merge(ex[:args])
      end
    end
  end
end
