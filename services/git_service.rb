require 'rugged'
require 'xa/rules/parse'

include XA::Rules::Parse

class GitService
  def self.init(clone_url, repo_name)
    repo = Rugged::Repository.clone_at(clone_url, File.join('.', repo_name), bare: true)
    # repo = Rugged::Repository.discover("./libgit2-test")
    res = parse_all(repo, scan_all(repo))

    clean(repo_name)

    res
  end

  def self.clean(repo_name)
    FileUtils.rm_rf(File.join('.', repo_name))
  end

  private

  def self.is_all_valid_extension?(files)
    files.all? {|o| is_valid_extension?(o[:name])}
  end

  def self.is_valid_extension?(name)
    ext = File.extname(name)
    Sinatra::Application.settings.allowed_formats.include?(ext[1..-1])
  end

  def self.is_rule_file?(name)
    ext = File.extname(name)
    ext[1..-1].to_sym == :rule
  end

  def self.is_package_file?(name)
    ext = File.extname(name)
    ext[1..-1].to_sym == :package
  end

  def self.scan_all(repo)
    br = repo.branches[Sinatra::Application.settings.git_branch]
    packages = {}
    
    # Iterate through the packages
    br.target.tree.each_tree do |o|
      files = repo.lookup(o[:oid]).inject([]) do |fs, o|
        fs.push o
      end

      if is_all_valid_extension?(files)
        id = o[:oid]
        packages[id] = files
      end
    end

    packages
  end

  def self.parse_all(repo, all)
    res = all.map do |id, files|
      if invalid_package_files repo, files
        return false
      end

      rule_file = files.find { |f| is_rule_file?(f[:name]) }
      oid = rule_file[:oid]
      blob = repo.lookup(oid)
      lines = blob.content.lines.map do |line|
        parse_single line.strip
      end

      lines.all? ? lines : false
    end

    res
  end

  def self.get_rule_file_name(name)
    File.basename name, ".*"
  end

  def self.invalid_package_files(repo, files)
    meta_file = files.find { |f| is_package_file?(f[:name]) }
    meta_oid = meta_file[:oid]

    blob = repo.lookup(meta_oid)

    meta = JSON.parse(blob.content)
    rules = meta["rules"]
    rules_files = files
      .select { |f| is_rule_file? f[:name] }
      .select { |f| rules.keys.include?(get_rule_file_name(f[:name]))}

    rules_files.length == 0
  end

  def self.parse_single(line)
    begin
      parse line
    rescue
      false
    end
  end
end
