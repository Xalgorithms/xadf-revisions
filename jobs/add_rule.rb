require 'sidekiq'
require 'xa/rules/parse/content'

require_relative '../lib/documents'
require_relative '../lib/tables'

$docs = Documents.new
$tables = Tables.new

module Jobs
  class AddRule
    include Sidekiq::Worker
    include XA::Rules::Parse::Content

    def perform(o)
      parsed = parse_rule(o['data'])
      # add the parsed rule into Mongo with the id
      public_id = $docs.store_rule(o.slice('ns', 'name', 'origin'), parsed)
      # add to the meta table in cassandra
      $tables.store_meta(
        ns:          o['ns'],
        name:        o['name'],
        origin:      o['origin'],
        branch:      o['branch'],
        rule_id:     public_id,
        version:     parsed.fetch('meta', {}).fetch('version', nil),
        runtime:     parsed.fetch('meta', {}).fetch('runtime', nil),
        criticality: parsed.fetch('meta', {}).fetch('criticality', nil),
      )
      # add to the effective table in cassandra
      effectives = parsed.fetch('effective', []).inject([]) do |eff_a, eff|
        eff_a + eff.fetch('jurisdictions', ['*']).inject([]) do |juri_a, juri|
          (country, region) = juri.split('-')
          juri_a + eff.fetch('keys', ['*']).map do |k|
            {
              rule_id:  public_id,
              country:  country,
              region:   region,
              key:      k,
              timezone: eff['timezone'],
              starts:   eff['starts'],
              ends:     eff['ends'],
            }
          end
        end
      end

      $tables.store_effectives(effectives)

      # NOTE: for now, the parser guarantees us that the left is
      # the reference and the right is the value to
      # match... Assuming this is very fragile thinking that
      # should eventually be changed
      applicables = parsed.fetch('whens', {}).inject([]) do |arr, (section, whens)|
        arr + whens.map do |wh|
          {
            section: section,
            key:     wh['expr']['left']['key'],
            op:      wh['expr']['op'],
            val:     wh['expr']['right']['value'],
            rule_id: public_id
          }
        end
      end
      $tables.store_applicables(applicables)
      
      false
    end
  end
end
