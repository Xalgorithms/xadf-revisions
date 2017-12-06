require 'rugged'
require 'xa/rules/parse'

include XA::Rules::Parse

class GitService
  def self.init()
    repo = Rugged::Repository.clone_at('https://github.com/hpilosyan/libgit2-test', File.join('.', 'libgit2-test'), bare: true)
    # repo = Rugged::Repository.discover("./libgit2-test")
    parse_all(repo, scan_all(repo))
  end

  def self.clean()
    FileUtils.rm_rf(File.join('.', 'libgit2-test'))
  end

  private

  def self.is_rule_file?(name)
    ext = File.extname(name)
    ext[1..-1].to_sym == :xalgo
  end

  def self.scan_all(repo)
    br = repo.branches['master']
    all_files = []
    
    br.target.tree.each_tree do |o|
      files = repo.lookup(o[:oid]).inject([]) do |fs, o|
        name = o[:name]
        is_rule_file?(name) ? fs.push(o[:oid]) : fs
      end
      all_files.concat files
    end

    all_files
  end

  def self.parse_all(repo, all)
    all.each do |oid|
      blob = repo.lookup(oid)
      blob.content.each_line do |line|
        parse_single line.strip
      end
    end

    clean()
  end

  def self.parse_single(line)
    begin
      parse line
    rescue
      puts "Failed to parse"
    end
  end
end
