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

require_relative '../../lib/tables'
require_relative '../../lib/ids'

describe Tables do
  include Radish::Randomness
  include Ids

  def rand_document_collection(ks)
    rand_array do
      ks.inject({}) do |o, k|
        o.merge(k => Faker::Lorem.word)
      end
    end
  end

  class Validation
    attr_reader :queries

    def initialize
      @queries = []
      @captures = [
        {
          regex: /INSERT INTO interlibr\.(.+) \((.+)\) VALUES \((.+)\)/,
          extract_fn: method(:extract_insert),
        },
        {
          regex: /UPDATE interlibr\.(.+) SET (.+\=.+) WHERE (.+)/,
          extract_fn: method(:extract_update),
        },
        {
          regex: /SELECT (.+) FROM interlibr\.([a-z]+)(?: WHERE ([^\;]+))?/,
          extract_fn: method(:extract_select),
        },
        {
          regex: /DELETE FROM interlibr.(.+) WHERE (.+)/,
          extract_fn: method(:extract_delete),
        },
      ]
    end

    def capture(q)
      q.split(';').each do |sub_q|
        exs = @captures.map do |cap|
          m = cap[:regex].match(sub_q)
          m ? cap[:extract_fn].call(m) : nil
        end.compact
        if exs.any?
          @queries << exs.first
        end
      end
    end

    def extract_insert(m)
      {
        tbl: m[1],
        keys: m[2].split(',').sort,
        vals: m[3].split(',').map { |s| s[1..-2] }.sort,
        op: :insert,
      }
    end

    def extract_update(m)
      {
        tbl: m[1],
        updates: m[2].split(/,\s*/).map do |s|
          (k, v) = s.split('=')
          { key: k, val: v }
        end,
        wheres: m[3].split(' AND ').map do |s|
          (k, v) = s.split('=')
          { key: k, val: v }
        end,
        op: :update
      }
    end

    def extract_select(m)
      {
        tbl: m[2],
        keys: m[1].split(',').sort,
        conds: m[3].split(' AND ').map do |c|
          (k, v) = c.split('=')
          { key: k, value: v }
        end
      }
    end

    def extract_delete(m)
      {
        tbl: m[1],
        conds: m[2].split(' AND ').inject({}) do |o, cond|
          (k, v) = cond.split('=')
          o.merge(k => v)
        end
      }
    end
  end
  
  def build_validation(tables, will_execute=true, results=nil)
    validate = Validation.new
    session = double('Fake: Cassandra session')
    stm = double('Fake: Cassandra statement')
    fut = double('Fake: future')
    
    expect(tables).to receive(:session).at_least(:once).and_return(session)

    if will_execute
      expect(session).to receive(:prepare).at_least(:once) do |q|
        validate.capture(q)
        stm
      end
      expect(session).to receive(:execute).at_least(:once).with(stm)
    end

    if results
      expect(session).to receive(:execute_async).at_least(:once) do |q|
        validate.capture(q)
        fut
      end
      expect(fut).to receive(:on_success).at_least(:once).and_yield(results)
      expect(fut).to receive(:join).at_least(:once)
    end

    validate
  end

  def check_one(ac, ex)
    expect(ac.keys.sort).to eql(ex.keys.sort)
    ac.each do |k, v|
      if v.class == Array
        expect(v).to match_array(ex[k])
      else
        expect(v).to eql(ex[k])
      end
    end
  end
  
  def check_many(validate, exs)
    expect(validate.queries.length).to eql(exs.length)
    validate.queries.each_with_index { |ac, i| check_one(ac, exs[i]) }
  end
  
  def check_first(validate, ex)
    check_one(validate.queries.first, ex)
  end
  
  def build_insert_expect_from_doc(tbl, doc)
    { tbl: tbl, keys: doc.keys.map(&:to_s).sort, vals: doc.values.sort, op: :insert }
  end

  it 'should store repositories' do
    keys = [:clone_url]

    rand_document_collection(keys).each do |o|
      tables = Tables.new
      validate = build_validation(tables)
      tables.store_repository(o)
      check_first(validate, build_insert_expect_from_doc('repositories', o))
    end
  end
  
  it 'should store meta data' do
    keys = [:ns, :name, :origin, :branch, :rule_id, :version, :runtime, :criticality]

    rand_document_collection(keys).each do |meta|
      tables = Tables.new
      validate = build_validation(tables)
      tables.store_meta(meta)

      exs = [
        {
          tbl: 'rules',
          op: :insert,
          keys: meta.keys.map(&:to_s),
          vals: meta.values,
        },
        {
          op: :update,
          tbl: 'rules_in_use',
          updates: [{key: 'refs', val: 'refs+1'}],
          wheres: [
            { key: 'rule_id', val: "'#{meta[:rule_id]}'" },
          ]
        }
      ]
      check_many(validate, exs)
    end
  end

  it 'should store applicables' do
    when_keys = [:section, :key]
    all_keys = when_keys + [:op, :val, :rule_id]

    rand_array do
      rand_document_collection(all_keys)
    end.each do |apps|
      tables = Tables.new
      validate = build_validation(tables)
      tables.store_applicables(apps)
      
      exes = apps.map do |app|
        {
          op: :update,
          tbl: 'when_keys',
          updates: [{key: 'refs', val: 'refs+1'}],
          wheres: [
            { key: 'section', val: "'#{app[:section]}'" },
            { key: 'key',     val: "'#{app[:key]}'" },
          ]
        }
      end + apps.map do |app|
        build_insert_expect_from_doc('whens', app)
      end

      check_many(validate, exes)
    end
  end

  it 'should store effectives' do
    keys = [:country, :region, :timezone, :starts, :ends, :key, :rule_id]
    rand_array do
      rand_document_collection(keys)
    end.each do |effs|
      tables = Tables.new
      validate = build_validation(tables)
      tables.store_effectives(effs)
      
      exes = effs.map do |eff|
        build_insert_expect_from_doc('effective', eff)
      end

      check_many(validate, exes)
    end
  end

  it 'should call back if a repository exists' do
    tables = Tables.new
    validate = build_validation(tables, false, [rand_document])
    url = Faker::Internet.url

    yielded = false
    tables.if_has_repository(url) do
      yielded = true
    end

    expect(yielded).to eql(true)
    ex = {
      tbl: 'repositories',
      keys: ['clone_url'],
      conds: [
        { key: 'clone_url', value: "'#{url}'" },
      ],
    }
    check_first(validate, ex)
  end

  it 'should not call back if a repository does not exist' do
    tables = Tables.new
    validate = build_validation(tables, false, [])
    url = Faker::Internet.url

    yielded = false
    tables.unless_has_repository(url) do
      yielded = true
    end

    expect(yielded).to eql(true)
    ex = {
      tbl: 'repositories',
      keys: ['clone_url'],
      conds: [
        { key: 'clone_url', value: "'#{url}'" },
      ],
    }
    check_first(validate, ex)
  end

  it 'should call back if a rule exists' do
    tables = Tables.new
    validate = build_validation(tables, false, [Faker::Number.hexadecimal(40).to_s])

    types = ['rule', 'table']
    exes = rand_array do
      ex = {
        ns: Faker::Lorem.word,
        name: Faker::Lorem.word,
        version: Faker::App.semantic_version,
        type: types.sample,
        branch: Faker::Lorem.word,
      }

      ex.merge(id: make_id(ex[:type], ex.slice(:ns, :name, :version).with_indifferent_access))
    end

    exes.each do |ex|
      yielded = false
      tables.if_has_rule(ex[:id], ex[:branch]) do
        yielded = true
      end

      expect(yielded).to eql(true)
    end

    queries = exes.map do |ex|
      ex = {
        tbl: 'rules',
        keys: ['rule_id'],
        conds: [
          { key: 'rule_id', value: "'#{ex[:id]}'" },
          { key: 'branch', value: "'#{ex[:branch]}'" },
        ],
      }
    end
    
    check_many(validate, queries)
  end

  it 'should not call back if a rule does not exist' do
    tables = Tables.new
    validate = build_validation(tables, false, [])

    types = ['rule', 'table']
    exes = rand_array do
      ex = {
        ns: Faker::Lorem.word,
        name: Faker::Lorem.word,
        version: Faker::App.semantic_version,
        type: types.sample,
        branch: Faker::Lorem.word,
      }

      ex.merge(id: make_id(ex[:type], ex.slice(:ns, :name, :version).with_indifferent_access))
    end

    exes.each do |ex|
      yielded = false
      tables.unless_has_rule(ex[:id], ex[:branch]) do
        yielded = true
      end

      expect(yielded).to eql(true)
    end

    queries = exes.map do |ex|
      ex = {
        tbl: 'rules',
        keys: ['rule_id'],
        conds: [
          { key: 'rule_id', value: "'#{ex[:id]}'" },
          { key: 'branch', value: "'#{ex[:branch]}'" },
        ],
      }
    end
    
    check_many(validate, queries)
  end

  it 'should yield rule_ids matching origin, branch' do
    tables = Tables.new
    rule_ids = rand_array { Faker::Number.hexadecimal(40) }
    validate = build_validation(tables, false,
                                OpenStruct.new(rows: rule_ids.map { |id| { 'rule_id' => id } })
                               )

    url = Faker::Internet.url
    branch = Faker::Lorem.word

    actual_rule_ids = []
    tables.lookup_rules_in_repo(url, branch) do |rule_id|
      actual_rule_ids << rule_id
    end

    expect(actual_rule_ids).to eql(rule_ids)

    check_first(validate,
                {
                  tbl: 'rules',
                  keys: ['rule_id'],
                  conds: [
                    { key: 'origin', value: "'#{url}'" },
                    { key: 'branch', value: "'#{branch}'"}
                  ]
                })
  end

  it 'should remove effectives by rule_id' do
    rand_times do
      rule_id = Faker::Number.hexadecimal(40)
      tables = Tables.new

      validate = build_validation(tables)

      expect(tables).to receive(:unless_rule_in_use).with(rule_id).and_yield
      tables.remove_effective(rule_id)

      check_first(validate, tbl: 'effective', conds: { 'rule_id' => "'#{rule_id}'" })
    end
  end

  it 'should not remove effectives if the rule is in use' do
    rand_times do
      rule_id = Faker::Number.hexadecimal(40)
      tables = Tables.new

      expect(tables).to receive(:unless_rule_in_use).with(rule_id)
      tables.remove_effective(rule_id)
    end
  end

  it 'should remove meta by origin, branch, rule_id' do
    rand_times(10) do
      origin = Faker::Internet.url
      branch = Faker::Lorem.word
      rule_id = Faker::Number.hexadecimal(40)

      tables = Tables.new

      validate = build_validation(tables, true)

      exs = [
        {
          tbl: 'rules',
          conds: {
            'origin' => "'#{origin}'",
            'branch' => "'#{branch}'",
            'rule_id' => "'#{rule_id}'",
          },
        },
        {
          op: :update,
          tbl: 'rules_in_use',
          updates: [{key: 'refs', val: 'refs-1'}],
          wheres: [
            { key: 'rule_id', val: "'#{rule_id}'" },
          ]
        }
      ]

      tables.remove_meta(origin, branch, rule_id)
      check_many(validate, exs)
    end
  end

  it 'should remove applicables by rule_id' do
    rand_times do
      rule_id = Faker::Number.hexadecimal(40)
      tables = Tables.new

      results = rand_array do
        { 'section' => Faker::Lorem.word, 'key' => Faker::Lorem.word }
      end
      
      validate = build_validation(tables, true, OpenStruct.new(rows: results))

      expect(tables).to receive(:unless_rule_in_use).with(rule_id).and_yield
      tables.remove_applicable(rule_id)

      exs = [
        {
          tbl: 'whens',
          keys: ['section', 'key'],
          conds: [
            { key: 'rule_id', value: "'#{rule_id}'" },
          ],
        }
      ] + results.map do |res|
        {
          op: :update,
          tbl: 'when_keys',
          updates: [{key: 'refs', val: 'refs-1'}],
          wheres: [
            { key: 'section', val: "'#{res['section']}'" },
            { key: 'key',     val: "'#{res['key']}'" },
          ]
        }
      end + [
        {
          tbl: 'whens',
          conds: { 'rule_id' => "'#{rule_id}'" }
        }
      ]
      check_many(validate, exs)
    end
  end

  it 'should not remove applicables if the rule is in use' do
    rand_times do
      rule_id = Faker::Number.hexadecimal(40)
      tables = Tables.new

      results = rand_array do
        { 'section' => Faker::Lorem.word, 'key' => Faker::Lorem.word }
      end
      
      validate = build_validation(tables, true, OpenStruct.new(rows: results))

      expect(tables).to receive(:unless_rule_in_use).with(rule_id)
      tables.remove_applicable(rule_id)

      exs = [
        {
          tbl: 'whens',
          keys: ['section', 'key'],
          conds: [
            { key: 'rule_id', value: "'#{rule_id}'" },
          ],
        }
      ] + results.map do |res|
        {
          op: :update,
          tbl: 'when_keys',
          updates: [{key: 'refs', val: 'refs-1'}],
          wheres: [
            { key: 'section', val: "'#{res['section']}'" },
            { key: 'key',     val: "'#{res['key']}'" },
          ]
        }
      end

      # the final delete in the previous test should be missing in this case
      
      check_many(validate, exs)
    end
  end
end
