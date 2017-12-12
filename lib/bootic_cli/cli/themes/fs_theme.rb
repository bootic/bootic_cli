require 'fileutils'

module BooticCli
  class FSTheme
    Template = Struct.new(:file_name, :body, :updated_on)
    ThemeAsset = Struct.new(:file_name, :file, :updated_on)

    ASSETS_DIR = 'assets'.freeze
    TEMPLATE_PATTERNS = ['*.liquid', '*.html', '*.css', '*.js', 'theme.yml'].freeze
    ASSET_PATTERNS = [File.join(ASSETS_DIR, '*')].freeze

    # helper to resolve the right type (Template or Asset) from a local path
    # this is not part of the generic Theme interface
    def self.resolve_type(path)
      path =~ /assets\// ? :asset : :template
    end

    def self.resolve_file(path)
      file = File.new(path)
      file_name = File.basename(path)
      type = resolve_type(path)

      item = if path =~ /assets\//
        ThemeAsset.new(file_name, file.read, file.mtime.utc)
      else
        Template.new(file_name, file.read, file.mtime.utc)
      end

      [item, type]
    end
    def initialize(dir)
      FileUtils.mkdir_p dir
      FileUtils.mkdir_p File.join(dir, ASSETS_DIR)
      @dir = dir
    end

    def templates
      @templates ||= (
        paths_for(TEMPLATE_PATTERNS).sort.map do |path|
          name = File.basename(path)
          file = File.new(path)
          Template.new(name, file.read, file.mtime.utc)
        end
      )
    end

    def assets
      @assets ||= (
        paths_for(ASSET_PATTERNS).sort.map do |path|
          fname = File.basename(path)
          file = File.new(path)
          ThemeAsset.new(fname, file, file.mtime.utc)
        end
      )
    end

    def add_template(file_name, body)
      path = File.join(dir, file_name)

      if !File.exist?(path) or !has_dos_line_endings?(path)
        body = normalize_endings(body)
      end

      File.open(path, 'w') do |io|
        io.write body
      end
      @templates = nil
    end

    def remove_template(file_name)
      path = File.join(dir, file_name)
      return false unless File.exists?(path)
      File.unlink path
      @templates = nil
    end

    def add_asset(file_name, file)
      path = File.join(dir, ASSETS_DIR, file_name)
      File.open(path, 'wb') do |io|
        io.write file.read
      end

      @assets = nil
    end

    def remove_asset(file_name)
      path = File.join(dir, ASSETS_DIR, file_name)
      return false unless File.exists?(path)

      File.unlink path
      @assets = nil
    end

    private

    attr_reader :dir

    def paths_for(patterns)
      patterns.reduce([]) {|m, pattern| m + Dir[File.join(dir, pattern)]}
    end

    def info
      @info ||= (
        path = File.join(dir, 'theme.yml')
        if File.exists?(path)
          YAML.load_file(path)
        else
          {}
        end
      )
    end

    def has_dos_line_endings?(path)
      !!IO.read(path)["\r\n"]
    end

    def normalize_endings(str)
      str.to_s.gsub(/\r\n?/, "\n")
    end
  end
end
