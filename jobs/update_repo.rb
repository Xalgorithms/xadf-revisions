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

require_relative './add_rule'
require_relative './add_table'
require_relative './add_data'
require_relative './remove_applicable'
require_relative './remove_effective'
require_relative './remove_meta'
require_relative './remove_rule'
require_relative './remove_stored_rules'
require_relative './remove_table'
require_relative './remove_data'
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
      @jobs = {
        update: {
          'rule'  => Jobs::AddRule,
          'table' => Jobs::AddTable,
          'json'  => Jobs::AddData,
        },
        remove: {
          'rule'  => Jobs::RemoveRule,
          'table' => Jobs::RemoveTable,
          'json'  => Jobs::RemoveData,
        },
      }

    end
    
    def perform(o)
      Storage.instance.tables.if_has_repository(o['url']) do
        @fns.fetch(o.fetch('what', 'unknown'), @default_fn).call(o)
      end
      
      false
    end

    private

    def invoke_jobs(ctx, items)
      items.each do |it|
        kl = @jobs[ctx].fetch(it[:type], nil)
        kl.perform_async(it) if kl
      end
    end
    
    def perform_branch_updated(o)
      gh = GitHub.new
      o.fetch('changes', []).each do |ch|
        items = gh.get_changed_files(o['url'], o['branch'], ch)
        jobs = [:remove, :update].zip(items.partition do |it|
                                        it[:op] == :removed
                                      end)

        jobs.each do |args|
          invoke_jobs(*args)
        end
      end
    end

    def perform_branch_created(o)
      gh = GitHub.new
      invoke_jobs(:update, gh.get(o['url'], o['branch']))
    end

    def perform_branch_removed(o)
      Storage.instance.tables.lookup_rules_in_repo(o['url'], o['branch']) do |rule_id|
        RemoveMeta.perform_async(origin: o['url'], branch: o['branch'], rule_id: rule_id)
        RemoveEffective.perform_async(rule_id: rule_id)
        RemoveApplicable.perform_async(rule_id: rule_id)
      end
      RemoveStoredRules.perform_async(origin: o['url'], branch: o['branch'])
    end
  end
end
