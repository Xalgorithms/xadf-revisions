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
require 'multi_json'
require 'sidekiq'

require_relative './add_xalgo'
require_relative './storage'

module Jobs
  class AddTable < AddXalgo
    include Sidekiq::Worker

    def initialize
      super('table')
    end

    def specific_classification(o, parsed)
      {}.tap do |rv|
        data = o.fetch('table_data', nil)
        if data && data.key?('type') && data.key?('content') && data['type'] == 'json'
          rv[:table_content] = MultiJson.decode(data['content'])
        end
      end
    end

    def perform_additional(o)
      Storage.instance.docs.store_table_data(o[:public_id], o[:table_content])
    end
  end
end
