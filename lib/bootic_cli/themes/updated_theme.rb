require 'diffy'

module BooticCli
  module Themes
    # given :source and :target themes,
    # UpdatedTheme computes assets and templates
    # with more recent versions in :source
    class UpdatedTheme
      TemplateWithDiff = Struct.new('TemplateWithDiff', :file_name, :body, :updated_on, :diff)

      def initialize(source:, target:, force_update: false)
        @source, @target = source, target
        # when doing a pull or push, we don't care if the other end has a more recent version
        # we only do that when syncing changes, in which case force_update should be false
        @force_update = force_update
      end

      def templates
        @templates ||= map_pair(source.templates, target.templates) do |a, b|
          diff = Diffy::Diff.new(normalize_endings(b.body), normalize_endings(a.body), context: 1)
          if !diff.to_s.empty? && should_update?(a, b)
            c = TemplateWithDiff.new(a.file_name, a.body, a.updated_on, diff)
            [true, c]
          else
            [false, nil]
          end
        end
      end

      def assets
        @assets ||= map_pair(source.assets, target.assets) do |a, b|
          [should_update?(a, b), a]
        end
      end

      private
      attr_reader :source, :target, :force_update

      def should_update?(a, b)
        force_update || more_recent?(a, b)
      end

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

      def normalize_endings(str)
        str.to_s.gsub(/\r\n?/, "\n")
      end
    end
  end
end
