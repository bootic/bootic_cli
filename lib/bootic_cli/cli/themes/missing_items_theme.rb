module BooticCli
  class MissingItemsTheme
    def initialize(source:, target:)
      @source, @target = source, target
    end

    def templates
      @templates ||= find_missing_files(source.templates, target.templates)
    end

    def assets
      @assets ||= find_missing_files(source.assets, target.assets)
    end

    private
    attr_reader :source, :target

    def find_missing_files(set1, set2)
      file_names = set2.map(&:file_name)
      set1.select do |f|
        !file_names.include?(f.file_name)
      end
    end
  end
end
