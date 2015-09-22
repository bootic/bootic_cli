module Btc
  class Console
    include Btc::Connectivity

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

      title 'Links:'
      puts links(entity.links)

      puts ''

      title 'Entities:'
      puts entity.entities.keys.join("\r\n")
      puts ''
    end

    private

    def table(hash)
      hash.map{|k,v| [k.to_s.ljust(20), v].join}.join("\r\n")
    end

    def title(str)
      puts str
      puts "------------------------------------"
    end

    def links(_links)
      table = _links.find_all{|k,v| v.is_a?(Hash)}.map do |rel, props|
        [rel.to_s.ljust(25), props['title'].to_s.ljust(50), props['href']].join
      end.join("\r\n")
    end
  end
end
