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

module Jobs
  class UpdateRepo
    include Sidekiq::Worker

    def initialize
      @fns = {
        'branch_updated' => method(:perform_branch_updated),
        'branch_created' => method(:perform_branch_created),
        'branch_removed' => method(:perform_branch_removed),
      }
      @default_fn = lambda do |o|
        puts "? unknown what (what=#{o.fetch('what', nil)})"
      end
    end
    
    def perform(o)
      Storage.instance.tables.if_has_repository(o['url']) do
        @fns.fetch(o.fetch('what', 'unknown'), @default_fn).call(o)
      end
      
      false
    end

    def perform_branch_updated(o)
      p [:branch_updated, o]
      # 1. clone @sha
      # 2. forall changes in the update, if the repo exists, spawn a
      # related job
      # 3. process 'removed'
    end

    def perform_branch_created(o)
      # 1. clone @sha
      # 2. forall files in the branch, if the repo exists, spawn a
      # related job
      p [:branch_created, o]
    end

    def perform_branch_removed(o)
      # 1. rules in this repo, from this branch need to be removed
      # 2. effectives with rule_ids from this branch need to be removed
      # 3. when_keys should be decremented
      # 4. whens should be removed
      p [:branch_removed, o]
    end
  end
end
