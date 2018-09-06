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
# This file was generated by the `rspec --init` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# The generated `.rspec` file contains `--require spec_helper` which will cause
# this file to always be loaded, without a need to explicitly require it in any
# files.
#
require 'multi_json'

require_relative '../services/actions'

describe 'Application' do
  include Radish::Randomness
  
  def last_response_json
    MultiJson.decode(last_response.body)
  end
  
  it 'should accept GET of /status' do
    get('/status')

    expect(last_response).to be_ok
    expect(last_response_json).to eql('status' => 'live')
  end
  
  it 'should accept POST of /actions' do
    payload = rand_document

    actions = double('Fake: actions')
    expect(Services::Actions).to receive(:instance).and_return(actions)
    expect(actions).to receive(:execute).with(payload)

    post('/actions', MultiJson.encode(payload))

    expect(last_response).to be_ok
    expect(last_response_json).to eql('status' => 'ok')    
  end
end
