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
module Services
  class Translate
    def initialize(documents, cassandra)
      @documents = documents
      @cassandra = cassandra
      documents.subscribe('meta', method(:translate_effective))
      documents.subscribe('rules', method(:translate_whens))
    end

    private
    
    def translate_effective(id)
      @documents.find_meta(id) do |doc|
        if 'rule' == doc['type']
          effs = doc.fetch('effective', []).map do |eff|
            {
              rule_id:  id,
              country:  doc.fetch('jurisdiction', {}).fetch('country', nil),
              region:   doc.fetch('jurisdiction', {}).fetch('region', nil),
              party:    doc.fetch('party', 'any'),
              timezone: eff['timezone'],
              starts:   eff['starts'],
              ends:     eff['ends'],
            }
          end
          @cassandra.store_effectives(effs)
        end
      end
    end

    def translate_whens(id)
      @documents.find_rule(id) do |doc|
        whens = doc['whens'].fetch('envelope', []).map do |wh|
          expr = wh['expr']
          # NOTE: for now, the parser guarantees us that the left is
          # the reference and the right is the value to
          # match... Assuming this is very fragile thinking that
          # should eventually be changed
          {
            section: expr['left']['section'],
            key:     expr['left']['key'],
            op:      expr['op'],
            val:     expr['right']['value'],
            rule_id: id
          }
        end

        @cassandra.store_whens(whens)
      end
    end
  end
end
