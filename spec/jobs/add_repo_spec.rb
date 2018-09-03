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
require 'faker'

require_relative '../../jobs/add_repo'
require_relative '../../jobs/add_rule'
require_relative '../../jobs/add_table'
require_relative '../../jobs/add_data'
require_relative '../../lib/github'

describe Jobs::AddRepo do
  include Radish::Randomness

  it "should download the repo using GitHub and schedule jobs for each relevant file" do
    jobs = {
      'rule'  => Jobs::AddRule,
      'table' => Jobs::AddTable,
      'json'  => Jobs::AddData,
    }

    url = 'https://github.com/Xalgorithms/testing-rules.git'
    github = double("GitHub")

    types = jobs.keys + [Faker::Lorem.word]
    contents = types.inject([]) do |a, t|
      a + rand_array do
        extra_fake_data = { a: Faker::Lorem.word, b: Faker::Lorem.word }
        { type: t }.merge(extra_fake_data)
      end
    end

    expect(GitHub).to receive(:new).and_return(github)
    expect(github).to receive(:get).with(url).and_return(contents)

    requests = { }

    jobs.each do |t, kl|
      expect(kl).to receive(:perform_async).at_least(:once) do |o|
        requests = requests.merge(t => (requests.fetch(t, []) + [o]))
      end
    end

    ex = contents.inject({}) do |o, con|
      o.merge(con[:type] => (o.fetch(con[:type], []) + [con]))
    end

    job = Jobs::AddRepo.new
    job.perform('url' => url)
  end
end
