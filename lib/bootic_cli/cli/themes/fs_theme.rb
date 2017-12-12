module BooticCli
  class FSTheme
    Template = Struct.new(:file_name, :body)
    ThemeAsset = Struct.new(:file_name, :file)

    ASSETS_DIR = 'assets'.freeze
    TEMPLATE_PATTERNS = ['*.liquid', '*.html', '*.css', '*.js', 'theme.yml'].freeze
    ASSET_PATTERNS = [File.join(ASSETS_DIR, '*')].freeze

    def initialize(dir)
      @dir = dir
    end

    def templates
      @templates ||= (
        paths_for(TEMPLATE_PATTERNS).sort.map do |path|
          name = File.basename(path)
          Template.new(name, File.read(path))
        end
      )
    end

    def assets
      @assets ||= (
        paths_for(ASSET_PATTERNS).sort.map do |path|
          fname = File.basename(path)
          ThemeAsset.new(fname, File.new(path))
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
