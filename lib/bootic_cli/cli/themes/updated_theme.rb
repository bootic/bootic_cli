require 'diffy'

module BooticCli
  # given :source and :target themes,
  # UpdatedTheme computes assets and templates
  # with more recent versions in :source
  class UpdatedTheme
    TemplateWithDiff = Struct.new('TemplateWithDiff', :file_name, :body, :updated_on, :diff)

    def initialize(source:, target:)
      @source, @target = source, target
    end

    def templates
      @templates ||= map_pair(source.templates, target.templates) do |a, b|
        diff = Diffy::Diff.new(b.body, a.body, context: 1)
        if more_recent?(a, b) && !diff.to_s.empty?
          c = TemplateWithDiff.new(a.file_name, a.body, a.updated_on, diff)
          [true, c]
        else
          [false, nil]
        end
      end
    end

    def assets
      @assets ||= map_pair(source.assets, target.assets) do |a, b|
        [more_recent?(a, b), a]
      end
    end

    private
    attr_reader :source, :target

    def more_recent?(a, b)
      a.updated_on > b.updated_on
    end

    def build_lookup(list)
      list.each_with_object({}) do |item, lookup|
        lookup[item.file_name] = item
      end
    end

    def map_pair(list1, list2, &block)
      lookup = build_lookup(list2)
      list1.each_with_object([]) do |item, arr|
        match = lookup[item.file_name]
        if match
          valid, item = yield(item, match)
          arr << item if valid
        end
      end
    end
  end
end
