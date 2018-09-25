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

require_relative '../lib/ids'
require_relative './remove_applicable'
require_relative './remove_effective'
require_relative './remove_meta'
require_relative './remove_stored_rule'

module Jobs
  class RemoveXalgo
    include Ids
    include Radish::Documents::Core
    include Sidekiq::Worker
    include XA::Rules::Parse::Content

    def initialize(doc_type)
      @doc_type = doc_type
    end
    
    def perform(o)
      ks = ['origin', 'branch', 'ns', 'name', 'data']
      (origin, branch, ns, name, data) = ks.map { |k| o.fetch(k, nil) }
      if origin && branch && ns && name && data
        parsed = send("parse_#{@doc_type}", data)
        id = { 'ns' => ns, 'name' => name, 'version' => get(parsed, 'meta.version', nil) }
        rule_id = make_id(@doc_type, id)
        RemoveMeta.perform_async(origin: origin, branch: branch, rule_id: rule_id)
        RemoveEffective.perform_async(rule_id: rule_id)
        RemoveApplicable.perform_async(rule_id: rule_id)
        RemoveStoredRule.perform_async(rule_id: rule_id)
      end
    end
  end
end
