require 'sidekiq/api'

stats = Sidekiq::Stats.new
stats.queues.keys.each do |n|
  q = Sidekiq::Queue.new(n)
  puts "! clearing #{n}"
  q.clear
end
