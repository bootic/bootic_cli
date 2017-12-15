require 'bootic_cli/cli/themes/updated_theme'
require 'bootic_cli/cli/themes/missing_items_theme'

module BooticCli
  class ThemeDiff
    def initialize(source:, target:)
      @source, @target = source, target
    end

    def updated_in_source
      @updated_in_source ||= UpdatedTheme.new(source: source, target: target)
    end

    def updated_in_target
      @updated_in_target ||= UpdatedTheme.new(source: target, target: source)
    end

    def missing_in_target
      @missing_in_target ||= MissingItemsTheme.new(source: source, target: target)
    end

    def missing_in_source
      @missing_in_source ||= MissingItemsTheme.new(source: target, target: source)
    end

    private
    attr_reader :source, :target
  end
end
