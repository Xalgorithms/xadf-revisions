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
require_relative './add_xalgo'

module Jobs
  class AddRule < AddXalgo
    def initialize
      super('rule')
    end
    
    def perform_additional(o)
      # NOTE: for now, the parser guarantees us that the left is
      # the reference and the right is the value to
      # match... Assuming this is very fragile thinking that
      # should eventually be changed
      applicables = o[:doc].fetch('whens', {}).inject([]) do |arr, (section, whens)|
        arr + whens.map do |wh|
          {
            section: section,
            key:     wh['expr']['left']['key'],
            op:      wh['expr']['op'],
            val:     wh['expr']['right']['value'],
            rule_id: o[:public_id],
          }
        end
      end
      Storage.instance.tables.store_applicables(applicables)
    end
  end
end
