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
require 'sidekiq'
require 'xa/rules/parse/content'

require_relative '../lib/documents'
require_relative '../lib/tables'

$docs = Documents.new
$tables = Tables.new

module Jobs
  class AddRule
    include Sidekiq::Worker
    include XA::Rules::Parse::Content

    def perform(o)
      parsed = parse_rule(o['data'])
      # add the parsed rule into Mongo with the id
      public_id = $docs.store_rule(o.slice('ns', 'name', 'origin'), parsed)
      # add to the meta table in cassandra
      $tables.store_meta(
        ns:          o['ns'],
        name:        o['name'],
        origin:      o['origin'],
        branch:      o['branch'],
        rule_id:     public_id,
        version:     parsed.fetch('meta', {}).fetch('version', nil),
        runtime:     parsed.fetch('meta', {}).fetch('runtime', nil),
        criticality: parsed.fetch('meta', {}).fetch('criticality', nil),
      )
      # add to the effective table in cassandra
      effectives = parsed.fetch('effective', []).inject([]) do |eff_a, eff|
        eff_a + eff.fetch('jurisdictions', ['*']).inject([]) do |juri_a, juri|
          (country, region) = juri.split('-')
          juri_a + eff.fetch('keys', ['*']).map do |k|
            {
              rule_id:  public_id,
              country:  country,
              region:   region,
              key:      k,
              timezone: eff['timezone'],
              starts:   eff['starts'],
              ends:     eff['ends'],
            }
          end
        end
      end

      $tables.store_effectives(effectives)

      # NOTE: for now, the parser guarantees us that the left is
      # the reference and the right is the value to
      # match... Assuming this is very fragile thinking that
      # should eventually be changed
      applicables = parsed.fetch('whens', {}).inject([]) do |arr, (section, whens)|
        arr + whens.map do |wh|
          {
            section: section,
            key:     wh['expr']['left']['key'],
            op:      wh['expr']['op'],
            val:     wh['expr']['right']['value'],
            rule_id: public_id
          }
        end
      end
      $tables.store_applicables(applicables)
      
      false
    end
  end
end
