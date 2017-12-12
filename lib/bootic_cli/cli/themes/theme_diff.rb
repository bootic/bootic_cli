require 'diffy'

module BooticCli
  module StringUtils
    def self.normalize_endings(str)
      str.to_s.gsub(/\r\n?/, "\n")
    end
  end

  class ThemeDiff
    ASSETS_DIR_EXP = /assets/

    def initialize(dir, theme, force_update = false)
      @local_files, @theme = Dir.glob(File.join(dir, '**/*')), theme
      @force_update = force_update

      # ensure local templates and assets are read/cached before any changes are made
      reload
    end

    def reload
      @cache = {}
      local_templates
      local_assets
      theme_templates
      theme_assets
      templates_updated_in_remote
      templates_updated_locally
    end

    def templates_updated_in_remote
      @cache[:updated_remote_templates] ||= find_modified_files(local_templates, theme_templates)
    end

    def templates_updated_locally
      @cache[:updated_local_templates] ||= find_modified_files(theme_templates, local_templates)
    end

    # templates in theme that are not in dir
    def remote_templates_not_in_dir
      @cache[:new_remote_templates] ||= find_missing_files(theme_templates, local_templates)
    end

    # assets in theme that are not in dir
    def remote_assets_not_in_dir
      @cache[:new_remote_assets] ||= find_missing_files(theme_assets, local_assets)
    end

    # templates in dir that are not in theme
    def local_templates_not_in_remote
      @cache[:new_local_templates] ||= find_missing_files(local_templates, theme_templates)
    end

    # assets in dir that are not in theme
    def local_assets_not_in_remote
      @cache[:new_local_assets] ||= find_missing_files(local_assets, theme_assets)
    end

    def local_templates
      @cache[:local_templates] ||= filtered_files { |path| !(path =~ ASSETS_DIR_EXP) }
    end

    def local_assets
      @cache[:local_assets] ||= filtered_files { |path| path =~ ASSETS_DIR_EXP && !File.directory?(path) }
    end

    private
    attr_reader :local_files, :theme, :force_update

    # This works as a theme template and theme asset
    # ThemeTemplate #file_name, #body
    # ThemeAsset #file_name, #file
    class LocalFile
      attr_reader :file_name, :file, :path
      attr_accessor :diff

      def initialize(path)
        @path = path
        @file_name = File.basename(path)
        @file = File.new(path)
      end

      def body
        @body ||= @file.read
      end

      def updated_on
        @file.mtime.utc.iso8601
      end
    end

    ModifiedFile = Struct.new('ModifiedFile', :file_name, :updated_on, :new_body, :diff)

    def find_missing_files(set1, set2)
      file_names = set2.map(&:file_name)
      set1.select do |f|
        !file_names.include?(f.file_name)
      end
    end

    # returns list of items from set1 that have a more recent timestamp in set2
    def find_modified_files(set1, set2)
      by_filename = {}
      set2.each { |f|
        by_filename[f.file_name] = { updated_on: f.updated_on, body: f.body }
      }

      set1.map do |f|
        other_file = by_filename[f.file_name]
        if other_file.nil?
          next
        end

        # normalize endings when comparing files so we don't have any noise in them
        diff = Diffy::Diff.new(StringUtils.normalize_endings(f.body), StringUtils.normalize_endings(other_file[:body]), context: 1)
        next if diff.to_s.empty?

        original_time = Time.parse f.updated_on
        updated_time  = Time.parse other_file[:updated_on]

        if !force_update && updated_time <= original_time
          next
        end

        ModifiedFile.new(f.file_name, other_file[:updated_on], other_file[:body], diff)
      end.compact
    end

    def theme_templates
      @cache[:theme_templates] ||= theme.templates
    end

    def theme_assets
      @cache[:theme_assets] ||= theme.assets
    end

    def filtered_files(&block)
      local_files.select(&block).map do |path|
        LocalFile.new(path)
      end
    end
  end
end
