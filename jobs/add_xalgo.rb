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

require_relative './storage'

module Jobs
  class AddXalgo
    include Sidekiq::Worker
    include XA::Rules::Parse::Content

    def initialize(doc_type)
      @doc_type = doc_type
    end
    
    def perform(o)
      parsed = send("parse_#{@doc_type}", o['data'])

      public_id = Storage.instance.docs.store_rule(@doc_type, o.slice('ns', 'name', 'origin'), parsed)
      store_meta(o, parsed, public_id)
      store_effectives(o, parsed, public_id)

      perform_additional(o, parsed, public_id)

      false
    end
    
    def perform_additional(o, parsed, public_id)
    end
    
    def store_meta(o, parsed, public_id)
      Storage.instance.tables.store_meta(
        ns:          o['ns'],
        name:        o['name'],
        origin:      o['origin'],
        branch:      o['branch'],
        rule_id:     public_id,
        version:     parsed.fetch('meta', {}).fetch('version', nil),
        runtime:     parsed.fetch('meta', {}).fetch('runtime', nil),
        criticality: parsed.fetch('meta', {}).fetch('criticality', nil),
      )
    end

    def store_effectives(o, parsed, public_id)
      effectives = parsed.fetch('effective', []).inject([]) do |eff_a, eff|
        eff_a + eff.fetch('jurisdictions', ['*']).inject([]) do |juri_a, juri|
          (country, *region_parts) = juri.split('-')
          juri_a + eff.fetch('keys', ['*']).map do |k|
            {
              rule_id:  public_id,
              country:  country,
              region:   region_parts.join('-'),
              key:      k,
              timezone: eff['timezone'],
              starts:   eff['starts'],
              ends:     eff['ends'],
            }
          end
        end
      end

      Storage.instance.tables.store_effectives(effectives)
    end
  end
end
