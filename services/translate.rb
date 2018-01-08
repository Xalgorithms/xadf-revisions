module Services
  class Translate
    def initialize(documents, cassandra)
      @documents = documents
      @cassandra = cassandra
      documents.subscribe('meta', method(:translate_effective))
      documents.subscribe('rules', method(:translate_whens))
    end

    private
    
    def translate_effective(id)
      @documents.find_meta(id) do |doc|
        if 'rule' == doc['type']
          effs = doc.fetch('effective', []).map do |eff|
            {
              rule_id:  id,
              country:  doc.fetch('jurisdiction', {}).fetch('country', nil),
              region:   doc.fetch('jurisdiction', {}).fetch('region', nil),
              party:    doc.fetch('party', 'any'),
              timezone: eff['timezone'],
              starts:   eff['starts'],
              ends:     eff['ends'],
            }
          end
          @cassandra.store_effectives(effs)
        end
      end
    end

    def translate_whens(id)
      @documents.find_rule(id) do |doc|
        whens = doc['whens'].fetch('envelope', []).map do |wh|
          expr = wh['expr']
          # NOTE: for now, the parser guarantees us that the left is
          # the reference and the right is the value to
          # match... Assuming this is very fragile thinking that
          # should eventually be changed
          {
            section: expr['left']['section'],
            key:     expr['left']['key'],
            op:      expr['op'],
            val:     expr['right']['value'],
            rule_id: id
          }
        end

        @cassandra.store_whens(whens)
      end
    end
  end
end
