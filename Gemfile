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
source 'https://rubygems.org'

ruby '2.4.2'

gem 'activesupport'
gem 'mongo'
gem 'multi_json'
gem 'puma'
gem 'redis'
gem 'sidekiq'
gem 'sinatra', "~> 2.0.1"
gem 'sinatra-contrib', "~> 2.0.1"
gem 'rugged'
gem 'uuid'
gem 'cassandra-driver'

gem 'xa-rules', git: 'https://github.com/Xalgorithms/xa-rules.git', tag: 'v0.4.0'
gem 'radish',   git: 'https://github.com/karfai/radish.git',        tag: 'v0.1.0'

group :development do
  gem 'rerun'
  gem 'pry'
end

group :test do
  gem 'faker'
  gem 'fuubar'
  gem 'rack-test'
  gem 'rspec'
end
