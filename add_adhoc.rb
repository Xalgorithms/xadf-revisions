require 'faker'
require 'faraday'
require 'faraday_middleware'

class Client
  def initialize
    @conn = Faraday.new('http://localhost:9292') do |f|
      f.request(:json) 
      f.response(:json, :content_type => /\bjson$/)
      f.adapter(Faraday.default_adapter)
    end
  end
  
  def send(name, thing, args)
    res = @conn.post('/actions', name: name, thing: thing, args: args)
    p [res.status, res.body]
  end
end

cl = Client.new
ns = Faker::Dune.planet.downcase

puts "> #{ns} / a_plus_b.rule"
cl.send('add', 'rule', {
          'ns' => ns,
          'name' => 'a_plus_b',
          'data' => IO.read('./spec/files/adhoc/a_plus_b.rule'),
        })

puts "> #{ns} / all_bs.table"
cl.send('add', 'table', {
          'ns' => ns,
          'name' => 'all_bs',
          'data' => IO.read('./spec/files/adhoc/all_bs.table'),
        })

puts "> #{ns} / all_bs.json"
cl.send('add', 'data', {
          'ns' => ns,
          'name' => 'all_bs',
          'data' => IO.read('./spec/files/adhoc/all_bs.json'),
        })

