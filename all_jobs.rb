Dir.glob('./jobs/*.rb').each do |fn|
  require_relative fn
end
