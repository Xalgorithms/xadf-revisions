require 'rugged'
require 'xa/rules/parse'

include XA::Rules::Parse

class GitService
  def self.init(clone_url, repo_name)
    repo = Rugged::Repository.clone_at(clone_url, File.join('.', repo_name), bare: true)
    # repo = Rugged::Repository.discover("./libgit2-test")
    success = parse_all(repo, scan_all(repo))

    clean(repo_name)

    success
  end

  def self.clean(repo_name)
    FileUtils.rm_rf(File.join('.', repo_name))
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
    all_lines = []
    all.each do |oid|
      blob = repo.lookup(oid)
      lines = blob.content.lines.map do |line|
        parse_single line.strip
      end

      all_lines.concat lines
    end

    all_lines.all?
  end

  def self.parse_single(line)
    begin
      parse line
    rescue
      false
    end
  end
end
