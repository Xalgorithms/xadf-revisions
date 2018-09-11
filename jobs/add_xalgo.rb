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
require 'radish/documents/core'
require 'sidekiq'
require 'xa/rules/parse/content'

require_relative './storage'
require_relative '../lib/ids'

module Jobs
  class AddXalgo
    include Ids
    include Radish::Documents::Core
    include Sidekiq::Worker
    include XA::Rules::Parse::Content

    def initialize(doc_type)
      @doc_type = doc_type
    end
    
    def perform(o)
      @classified = parse_and_classify(o)

      Storage.instance.docs.store_rule(
        @doc_type,
        @classified[:public_id],
        @classified[:meta],
        @classified[:doc],
      )
      store_meta
      store_effectives

      perform_additional(@classified)

      false
    end

    private

    def parse_and_classify(o)
      parsed = send("parse_#{@doc_type}", o['data'])
      meta = {
        ns: o['ns'],
        name: o['name'],
        origin: o['origin'],
        branch: o['branch'],
        version: get(parsed, 'meta.version', nil),
        runtime: get(parsed, 'meta.runtime', nil),
        criticality: get(parsed, 'meta.criticality', 'normal'),
      }

      {
        public_id: make_id(@doc_type, meta.slice(:ns, :name, :version).with_indifferent_access),
        meta: meta,
        doc: parsed,
      }
    end
    
    def perform_additional(classified)
    end
    
    def store_meta
      Storage.instance.tables.store_meta(@classified[:meta].merge(rule_id: @classified[:public_id]))
    end

    def store_effectives
      effectives = @classified[:doc].fetch('effective', []).inject([]) do |eff_a, eff|
        eff_a + eff.fetch('jurisdictions', ['*']).inject([]) do |juri_a, juri|
          (country, *region_parts) = juri.split('-')
          juri_a + eff.fetch('keys', ['*']).map do |k|
            {
              rule_id:  @classified[:public_id],
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
