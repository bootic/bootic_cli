require 'bootic_cli/themes/updated_theme'
require 'bootic_cli/themes/missing_items_theme'

module BooticCli
  module Themes
    class ThemeDiff
      def initialize(source:, target:, force_update:)
        @source, @target = source, target
        @force_update = force_update
      end

      def updated_in_source
        @updated_in_source ||= UpdatedTheme.new(source: source, target: target, force_update: force_update)
      end

      def updated_in_target
        @updated_in_target ||= UpdatedTheme.new(source: target, target: source, force_update: force_update)
      end

      def missing_in_target
        @missing_in_target ||= MissingItemsTheme.new(source: source, target: target)
      end

      def missing_in_source
        @missing_in_source ||= MissingItemsTheme.new(source: target, target: source)
      end

      private
      attr_reader :source, :target, :force_update
    end
  end
end
