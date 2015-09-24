module Btc
  class Console
    include Btc::Connectivity

    SEPCOUNT = 40.freeze

    def initialize(root = root)
      @root = root
    end

    def explain(entity)
      if entity.is_a?(String) || entity.is_a?(Integer)
        puts entity
        return
      end

      if entity.is_a?(Array)
        entity.each{|e| explain(e) }
        return
      end

      title 'Properties:'
      puts table(entity.properties)

      puts ''

      title 'Links (explain_link <ENTITY>, <LINK_NAME>):'
      puts links(entity.rels)

      puts ''

      title 'Entities (explain <SUBENTITY>):'
      puts entity.entities.keys.join("\r\n")

      puts '=' * SEPCOUNT
      puts ''
      nil
    end

    def explain_link(entity, key)
      return "This entity does not appear to have links" unless entity.respond_to?(:rels)
      rel = entity.rels[key.to_sym]
      return "This entity does not have link '#{key}'" unless rel

      data = [
        ['name', key],
        ['type', rel.type],
        ['title', rel.title],
        ['method', rel.transport_method],
        ['docs', rel.docs],
        ['href', rel.href],
        ['parameters', rel.parameters.join(', ')]
      ]

      puts table(data)
      puts ''
      token = session.config[:access_token]
      puts %(curl -i -H "Authorization: Bearer #{token}" "#{rel.href}")

      nil
    end

    def list(entities)
      if entities.respond_to?(:each)
        entities.each{|e| explain(e)}
        puts ''
        puts "Page #{entities.page} of #{entities.total_items / entities.per_page}"
        if entities.has?(:next)
          @last_in_list = entities
          puts "There is more. run 'more'"
        else
          @last_in_list = nil
          puts "End of list"
        end
      else
        explain entities
      end

      nil
    end

    def more
      puts "End of list" unless @last_in_list
      list @last_in_list.next
    end

    private

    def table(hash)
      hash.map{|k,v| [k.to_s.ljust(20), v].join}.join("\r\n")
    end

    def title(str)
      puts str
      puts "-" * SEPCOUNT
      nil
    end

    def links(rels)
      table = rels.map do |key, relation|
        [key.to_s.ljust(25), relation.title.to_s.ljust(50)].join
      end.join("\r\n")
    end
  end
end
