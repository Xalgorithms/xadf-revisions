require_relative '../jobs/add_repo'

module Services
  class Actions
    def execute(o)
      @actions ||= {
        add: {
          repository: Jobs::AddRepo
        }
      }

      n = o.fetch('name', nil).to_sym
      th = o.fetch('thing', nil).to_sym
      act = @actions.fetch(n, {}).fetch(th, nil)
      if act
        puts "> enqueuing action (act=#{act})"
        act.perform_async(o.fetch('args', {}))
        puts "< enqueued action (act=#{act})"
      else
        puts "? unknown action (n=#{n}; th=#{th})"
      end
    end
  end
end
