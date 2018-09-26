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

require_relative './storage'
require_relative '../lib/ids'

module Jobs
  class RemoveSpecificXalgo
    include Ids
    include Sidekiq::Worker

    def initialize(doc_type)
      @doc_type = doc_type
    end
    
    def perform(o)
      ks = ['ns', 'name', 'version']
      (ns, name, version) = ks.map { |k| o.fetch(k, nil) }

      if ns && name && version
        rule_id = make_id(@doc_type, 'ns' => ns, 'name' => name, 'version' => version)
        Storage.instance.docs.remove_rule_by_id(rule_id)
        Storage.instance.tables.purge_rule(rule_id)
      end
    end
  end
end
