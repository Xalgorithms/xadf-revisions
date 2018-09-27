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
require 'logger'
require 'singleton'

class LocalLogger
  include Singleton

  def self.info(m, vals)
    LocalLogger.instance.info(m, vals)
  end

  def self.error(m, vals)
    LocalLogger.instance.error(m, vals)
  end

  def self.warn(m, vals)
    LocalLogger.instance.warn(m, vals)
  end

  def self.debug(m, vals)
    LocalLogger.instance.debug(m, vals)
  end

  def self.give(m, vals)
    LocalLogger.instance.give(m, vals)
  end

  def self.got(m, vals)
    LocalLogger.instance.got(m, vals)
  end

  def initialize
    @logger = nil
    if ENV.fetch('RACK_ENV', nil) != 'test'
      @logger = Logger.new(STDOUT)
    end
  end
  
  def info(m, vals)
    @logger.info(format_log('#', m, vals)) if @logger
  end

  def error(m, vals)
    @logger.error(format_log('!', m, vals)) if @logger
  end

  def warn(m, vals)
    @logger.warn(format_log('?', m, vals)) if @logger
  end

  def debug(m, vals)
    @logger.debug(format_log('##', m, vals)) if @logger
  end

  def give(m, vals)
    @logger.info(format_log('>', m, vals)) if @logger
  end

  def got(m, vals)
    @logger.info(format_log('<', m, vals)) if @logger
  end

  private

  def format_log(sigil, m, vals)
    vs = vals.map { |k, v| "#{k}=#{v}" }.join('; ')
    "#{sigil} #{m} (#{vs})"
  end
end
