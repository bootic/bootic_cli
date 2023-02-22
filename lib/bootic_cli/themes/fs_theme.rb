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
            # puts "Other has no digest, so comparing dates: #{self.updated_on} vs #{other.updated_on}"
            return self.updated_on.to_i == other.updated_on.to_i
          end

          # file sizes may differ as they are served by CDN (that shrinks them)
          # puts "Comparing digests:\n#{digest}\n#{other.digest}"
          self.digest == other.digest # self.file_size == other.file_size
        end
      end

      ASSETS_DIR = 'assets'.freeze
      TEMPLATE_PATTERNS = ['sections/*.html', '*.html', '*.css', '*.js', '*.json', 'theme.yml'].freeze
      ASSET_PATTERNS = [File.join(ASSETS_DIR, '*')].freeze

      def self.resolve_path(path, dir)
        File.expand_path(path).sub(File.expand_path(dir) + '/', '')
      end

      # helper to resolve the right type (Template or Asset) from a local path
      # this is not part of the generic Theme interface
      def self.resolve_type(path)
        path =~ /assets\// ? :asset : :template
      end

      def self.resolve_file(path, workdir)
        file = File.new(path)
        type = resolve_type(path)

        # initialize a new asset or template as it might be a new file
        item = if path =~ /assets\//
          file_name = File.basename(path)
          ThemeAsset.new(file_name, file, file.mtime.utc)
        else
          file_name = resolve_path(path, workdir)
          Template.new(file_name, file.read, file.mtime.utc)
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
          paths_for(TEMPLATE_PATTERNS).sort.map do |path|
            name = self.class.resolve_path(path, dir)
            file = File.new(path)
            Template.new(name, file.read, file.mtime.utc)
          end
        )
      end

      def assets
        @assets ||= (
          paths_for(ASSET_PATTERNS).sort.map do |path|
            if File.file?(path)
              fname = File.basename(path)
              file = File.new(path)
              ThemeAsset.new(fname, file, file.mtime.utc)
            end
          end.compact
        )
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
        path = File.join(dir, ASSETS_DIR, file_name)
        File.open(path, 'wb') do |io|
          io.write file.read
        end

        @assets = nil
      end

      def remove_asset(file_name)
        path = File.join(dir, ASSETS_DIR, file_name)
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
