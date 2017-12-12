require 'diffy'

module BooticCli
  module StringUtils
    def self.normalize_endings(str)
      str.to_s.gsub(/\r\n?/, "\n")
    end
  end

  class ThemeDiff
    ASSETS_DIR_EXP = /assets/

    def initialize(source:, target:, force_update: false)
      @source, @target = source, target
      @force_update = force_update
    end

    def templates_updated_in_source
      find_modified_files(target.templates, source.templates)
    end

    def templates_updated_in_target
      find_modified_files(source.templates, target.templates)
    end

    def source_templates_not_in_target
      find_missing_files(source.templates, target.templates)
    end

    def target_templates_not_in_source
      find_missing_files(target.templates, source.templates)
    end

    def source_assets_not_in_target
      find_missing_files(source.assets, target.assets)
    end

    def target_assets_not_in_source
      find_missing_files(target.assets, source.assets)
    end

    private
    attr_reader :source, :target, :force_update

    ModifiedFile = Struct.new('ModifiedFile', :file_name, :updated_on, :body, :diff)

    def find_missing_files(set1, set2)
      file_names = set2.map(&:file_name)
      set1.select do |f|
        !file_names.include?(f.file_name)
      end
    end

    # returns list of items from set1 that have a more recent timestamp in set2
    def find_modified_files(set1, set2)
      by_filename = set2.each_with_object({}) do |f, lookup|
        lookup[f.file_name] = f
      end

      set1.map do |f|
        other_file = by_filename[f.file_name]
        if other_file.nil?
          next
        end

        # normalize endings when comparing files so we don't have any noise in them
        diff = Diffy::Diff.new(StringUtils.normalize_endings(f.body), StringUtils.normalize_endings(other_file.body), context: 1)
        next if diff.to_s.empty?

        if !force_update && other_file.updated_on <= f.updated_on
          next
        end

        ModifiedFile.new(f.file_name, other_file.updated_on, other_file.body, diff)
      end.compact
    end
  end
end
