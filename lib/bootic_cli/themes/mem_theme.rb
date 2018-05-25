module BooticCli
  module Themes
    class MemTheme
      Template = Struct.new(:file_name, :body, :updated_on)
      ThemeAsset = Struct.new(:file_name, :file, :updated_on, :file_size)

      def initialize
        reload!
      end

      # Implement generic Theme interface
      attr_reader :templates, :assets

      def public?
        false # just for tests
      end

      def path
        nil
      end

      def reload!
        @templates = []
        @assets = []
      end

      def add_template(file_name, body, mtime: Time.now)
        tpl = Template.new(file_name, body, mtime)
        if idx = templates.index { |t| t.file_name == file_name }
          templates[idx] = tpl
        else
          templates << tpl
        end
      end

      def remove_template(file_name)
        if idx = templates.index { |t| t.file_name == file_name }
          templates.delete_at idx
        end
      end

      def add_asset(file_name, file, mtime: Time.now)
        asset = ThemeAsset.new(file_name, file, mtime)
        if idx = assets.index { |t| t.file_name == file_name }
          assets[idx] = asset
        else
          assets << asset
        end
      end

      def remove_asset(file_name)
        if idx = assets.index { |t| t.file_name == file_name }
          assets.delete_at idx
        end
      end
    end
  end
end
