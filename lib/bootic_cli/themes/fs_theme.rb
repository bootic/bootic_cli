require 'fileutils'
require 'yaml/store'
require 'digest/md5'

module BooticCli
  module Themes
    class FSTheme

      Template = Struct.new(:file_name, :body, :updated_on) do
        def ==(other)
          self.updated_on.to_i == other.updated_on.to_i
        end
      end

      ThemeAsset = Struct.new(:file_name, :file, :updated_on) do
        def body; @body ||= file.read; end
        def file_size; body.length; end
        def digest; @digest ||= Digest::MD5.hexdigest(body); end

        def ==(other)
          if other.digest.to_s == '' # api theme asset without a digest set
            # puts "Other has no digest, so comparing dates: #{self.updated_on.to_i} vs #{other.updated_on.to_i}"
            return self.updated_on.to_i == other.updated_on.to_i
          end

          # file sizes may differ as they are served by CDN (that shrinks them)
          # puts "Comparing FSTheme vs other digest:\n#{digest}\n#{other.digest}"
          self.digest == other.digest # self.file_size == other.file_size
        end
      end

      ASSETS_DIR  = 'assets'.freeze
      PUBLIC_DIR  = 'public'.freeze

      TEMPLATE_PATTERNS = [
        '*.html', '*.css', '*.js', '*.json', '*.yml',
        'sections/*.html', 'partials/*.html', 'data/*.json', 'data/*.yml'
      ].freeze
      # v2 themes organise templates under layouts/, templates/, and strings/
      V2_TEMPLATE_PATTERNS = [
        File.join('layouts',   '*.{html,liquid}'),
        File.join('templates', '*.{html,liquid}'),
        File.join('strings',   '*.json'),
      ].freeze

      ASSET_PATTERNS    = [File.join(ASSETS_DIR, '*')].freeze
      V2_ASSET_PATTERNS = [File.join(PUBLIC_DIR, '**', '*')].freeze

      ASSET_PATH_REGEX        = /^assets\/[^\/]+$/.freeze
      V2_ASSET_PATH_REGEX     = /^public\/(.+)$/.freeze   # captures subpath without 'public/'
      TEMPLATE_PATH_REGEX     = /^[^\/]+\.(html|css|scss|js|json|yml)$/.freeze
      SECTION_PATH_REGEX      = /^(sections|partials)\/[^\/]+\.html$/.freeze
      DATA_PATH_REGEX         = /^data\/[^\/]+\.(json|yml)$/.freeze
      V2_TEMPLATE_PATH_REGEX  = /^(layouts|templates)\/[^\/]+\.(html|liquid)$/.freeze
      STRINGS_PATH_REGEX      = /^strings\/[^\/]+\.json$/.freeze

      def self.resolve_path(path, dir)
        File.expand_path(path).sub(File.expand_path(dir) + '/', '')
      end

      # helper to resolve the right type (Template or Asset) from a local path
      # this is not part of the generic Theme interface
      def self.resolve_type(path, dir)
        relative_path = resolve_path(path, dir)

        if relative_path[ASSET_PATH_REGEX] || relative_path[V2_ASSET_PATH_REGEX]
          :asset
        elsif relative_path[TEMPLATE_PATH_REGEX] ||
              relative_path[SECTION_PATH_REGEX]   ||
              relative_path[DATA_PATH_REGEX]       ||
              relative_path[V2_TEMPLATE_PATH_REGEX]||
              relative_path[STRINGS_PATH_REGEX]
          :template
        end
      end

      def self.resolve_file(path, workdir)
        unless type = resolve_type(path, workdir)
          return # neither an asset nor a template
        end

        file = File.new(path)
        relative_path = resolve_path(path, workdir)

        item = if type == :asset
          # v2 assets live under public/ — strip the prefix so file_name matches
          # what the API stores (e.g. "css/main.css" not "public/css/main.css")
          file_name = if (m = relative_path.match(V2_ASSET_PATH_REGEX))
            m[1]
          else
            File.basename(path)
          end
          ThemeAsset.new(file_name, file, file.mtime.utc)
        else
          Template.new(relative_path, file.read, file.mtime.utc)
        end

        [item, type]
      end

      def initialize(dir, subdomain: nil)
        @dir = dir
        @setup = false
        @subdomain = subdomain
      end

      def subdomain
        @subdomain || read_subdomain
      end

      def write_subdomain
        store.transaction do
          store['subdomain'] = @subdomain
        end
      end

      def reset!
        return false unless @setup
        FileUtils.rm_rf dir
      end

      def path
        File.expand_path(dir)
      end

      # Implement generic Theme interface
      def reload!
        @templates = nil
        @assets = nil
      end

      def templates
        @templates ||= (
          paths_for(TEMPLATE_PATTERNS + V2_TEMPLATE_PATTERNS).map do |path|
            name = self.class.resolve_path(path, dir)
            file = File.new(path)
            Template.new(name, file.read, file.mtime.utc)
          end
        )
      end

      def assets
        @assets ||= begin
          v1 = paths_for(ASSET_PATTERNS).select { |p| File.file?(p) }.sort.map do |path|
            ThemeAsset.new(File.basename(path), File.new(path), File.new(path).mtime.utc)
          end

          public_base = File.join(dir, PUBLIC_DIR)
          v2 = paths_for(V2_ASSET_PATTERNS).select { |p| File.file?(p) }.sort.map do |path|
            subpath = path.sub("#{public_base}/", '')
            ThemeAsset.new(subpath, File.new(path), File.new(path).mtime.utc)
          end

          v1 + v2
        end
      end

      def add_template(file_name, body)
        setup
        path = File.join(dir, file_name)

        # remove DOS line endings for new templates
        # or for existing ones that don't have any.
        if !File.exist?(path) or !has_dos_line_endings?(path)
          body = body.gsub(/\r\n?/, "\n")
        end

        dir = File.dirname(path)
        FileUtils.mkdir_p(dir) unless File.exist?(dir)

        File.open(path, 'w') do |io|
          io.write(body)
        end

        @templates = nil
      end

      def remove_template(file_name)
        path = File.join(dir, file_name)
        return false unless File.exist?(path)
        File.unlink path
        @templates = nil
      end

      def add_asset(file_name, file)
        setup
        # v2 assets have a subpath like "css/main.css"; v1 are bare filenames
        path = if file_name.include?('/')
          File.join(dir, PUBLIC_DIR, file_name)
        else
          File.join(dir, ASSETS_DIR, file_name)
        end
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, 'wb') { |io| io.write file.read }
        @assets = nil
      end

      def remove_asset(file_name)
        path = if file_name.include?('/')
          File.join(dir, PUBLIC_DIR, file_name)
        else
          File.join(dir, ASSETS_DIR, file_name)
        end
        return false unless File.exist?(path)
        File.unlink path
        @assets = nil
      end

      private

      attr_reader :dir

      def has_dos_line_endings?(path)
        !!IO.read(path)["\r\n"]
      end

      def paths_for(patterns)
        patterns.reduce([]) do |m, pattern|
          m + Dir[File.join(dir, pattern)]
        end
      end

      def setup
        return self if @setup
        FileUtils.mkdir_p dir
        FileUtils.mkdir_p File.join(dir, ASSETS_DIR)
        @setup = true
        self
      end

      def store
        @store ||= (
          setup
          YAML::Store.new(File.join(path, '.state'))
        )
      end

      def read_subdomain
        store.transaction { store['subdomain'] }
      end
    end
  end
end
