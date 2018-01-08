require 'mongo'

cl = Mongo::Client.new('mongodb://127.0.0.1:27017/xadf')
['meta', 'rules', 'tables'].each do |cn|
  cl[cn].delete_many({})
end
