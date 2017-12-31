require_relative './services/github'

gh = Services::GitHub.new
gh.process('https://github.com/Xalgorithms/xadf-examples-general.git') do |packages|
  p packages
end
