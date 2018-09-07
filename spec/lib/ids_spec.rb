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
require 'digest'
require 'faker'

require_relative '../../lib/ids'

describe Ids do
  include Radish::Randomness
  include Ids

  it 'should generate an id based on ns, name, version' do
    types = ['rule', 'table']
    rand_array do
      {
        'type'    => types.sample,
        'ns'      => "#{Faker::Lorem.word}",
        'name'    => "#{Faker::Lorem.word}",
        'version' => "#{Faker::App.semantic_version}",
      }
    end.each do |vals|
      k = "#{vals['type'].first.capitalize}(#{vals['ns']}:#{vals['name']}:#{vals['version']})"
      id = Digest::SHA1.hexdigest(k)

      expect(make_id(vals['type'], vals.slice('ns', 'name', 'version'))).to eql(id)
    end
  end
end
