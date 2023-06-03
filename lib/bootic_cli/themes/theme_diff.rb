require 'bootic_cli/themes/updated_theme'
require 'bootic_cli/themes/missing_items_theme'

module BooticCli
  module Themes
    class ThemeDiff
      def initialize(source:, target:, force_update: false)
        @source, @target = source, target
        @force_update = force_update
      end

      def summary
        msg = []
        msg.push(" - Updated in source: #{updated_in_source.count}") if updated_in_source.any?
        msg.push(" - Updated in target: #{updated_in_target.count}") if updated_in_target.any?
        msg.push(" - Missing in target: #{missing_in_target.count}") if missing_in_target.any?
        msg.push(" - Missing in source: #{missing_in_source.count}") if missing_in_source.any?
        msg.unshift("Summary:") if msg.any?
        msg.join("\n")
      end

      def any?
        updated_in_source.any? || updated_in_target.any? || missing_in_target.any? || missing_in_source.any?
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
