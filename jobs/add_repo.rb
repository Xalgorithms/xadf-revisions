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

require_relative '../lib/github'
require_relative './add_rule'
require_relative './add_table'
require_relative './add_data'
require_relative './storage'

module Jobs
  class AddRepo
    include Sidekiq::Worker

    def perform(o)
      @github ||= GitHub.new
      @jobs ||= {
        'rule'  => Jobs::AddRule,
        'table' => Jobs::AddTable,
        'json'  => Jobs::AddData,
      }

      url = o.fetch('url', nil)
      if url
        items = @github.get(url)
        Jobs::Storage.instance.tables.store_repository(clone_url: url)
        items.each do |o|
          job_kl = @jobs.fetch(o[:type], nil)
          if job_kl
            job_kl.perform_async(o)
          else
            LocalLogger.error('no job class found', type: o[:type])
          end
        end
      else
        LocalLogger.warn('no url provided')
      end

      false
    end
  end
end
