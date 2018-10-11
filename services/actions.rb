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
require 'singleton'

require_relative '../jobs/add_repo'
require_relative '../jobs/add_adhoc_rule'
require_relative '../jobs/add_adhoc_table'
require_relative '../jobs/remove_specific_rule'
require_relative '../jobs/remove_specific_table'
require_relative '../jobs/remove_repo'
require_relative '../jobs/update_repo'
require_relative '../lib/local_logger'

module Services
  class Actions
    include Singleton
    
    def execute(o)
      @actions ||= {
        add: {
          repository: Jobs::AddRepo,
          rule:       Jobs::AddAdhocRule,
          table:      Jobs::AddAdhocTable,
        },
        update: {
          repository: Jobs::UpdateRepo,
        },
        remove: {
          repository: Jobs::RemoveRepo,
          rule:       Jobs::RemoveSpecificRule,
          table:      Jobs::RemoveSpecificTable,
        },
      }

      n = o.fetch('name', nil).to_sym
      th = o.fetch('thing', nil).to_sym
      act = @actions.fetch(n, {}).fetch(th, nil)
      if act
        LocalLogger.give('enqueuing action', act: act)
        act.perform_async(o.fetch('args', {}))
        LocalLogger.got('enqueued action', act: act)
      else
        LocalLogger.warn('unknown action', n: n, th: th)
      end
    end
  end
end
