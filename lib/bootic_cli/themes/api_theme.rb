require 'time'
require 'bootic_cli/utils'

module BooticCli
  module Themes
    class ItemWithTime < SimpleDelegator
      def updated_on
        Time.parse(super)
      end

      def ==(other)
        # puts "Comparing with time #{self.updated_on} vs #{other.updated_on}"
        self.updated_on == other.updated_on
      end
    end

    class APIAsset < ItemWithTime
      def file
        @file ||= BooticCli::Utils.fetch_http_file(rels[:file].href)
      end

      def ==(other)
        if digest.to_s == '' || other.digest.to_s == ''
          # puts "One or the other digest is empty: #{digest} -- #{other.digest}"
          return super
        end

        # file sizes may differ as they are served by CDN (that shrinks them)
        self.digest == other.digest # && self.file_size == other.file_size
      end
    end

    class APITheme

      class EntityErrors < StandardError
        attr_reader :errors
        def initialize(errors)
          @errors = errors
          super "Entity has errors: #{errors.map(&:field).join(', ')}"
        end
      end

      def initialize(theme)
        @theme = theme
        puts "Entity has errors: #{theme.errors.map(&:messages).join(', ')}" if theme.has?(:errors)
      end

      # this is unique to API themes
      def public?
        !dev?
      end

      def dev?
        theme.can?(:publish_theme)
      end

      def publish(opts = {})
        if theme.can?(:publish_theme)
          @theme = theme.publish_theme(opts)
          reload!(false)
        end
      end

      def path
        theme.rels[:theme_preview].href
      end

      # Implement generic Theme interface
      def reload!(refetch = true)
        @templates = nil
        @assets = nil
        @theme = theme.self if refetch
        self
      end

      def templates
        @templates ||= theme.templates.map { |t| ItemWithTime.new(t) }
      end

      def assets
        @assets ||= theme.assets.map { |t| APIAsset.new(t) }
      end

      def add_template(file_name, body)
        check_errors! theme.create_template(
          file_name: file_name,
          body: body
        )
      end

      def remove_template(file_name)
        tpl = theme.templates.find { |t| t.file_name == file_name }
        if tpl && tpl.can?(:delete_template)
          res = tpl.delete_template
          check_errors!(res) if res.respond_to?(:can?)
        else
          puts "Cannot delete #{file_name}"
        end
      end

      def add_asset(file_name, file)
        check_errors! theme.create_theme_asset(
          file_name: file_name,
          data: file
        )
      end

      def remove_asset(file_name)
        asset = theme.assets.find { |t| t.file_name == file_name }
        if asset and asset.can?(:delete_theme_asset)
          res = asset.delete_theme_asset
          check_errors!(res) if res.respond_to?(:can?)
        else
          puts "Cannot delete asset: #{file_name}"
        end
      end

      private
      attr_reader :theme

      def check_errors!(entity)
        if entity.has?(:errors)
          raise EntityErrors.new(entity.errors)
        end

        entity
      end
    end
  end
end
