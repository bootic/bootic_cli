require 'time'
require 'net/http'

module BooticCli
  module Themes
    class ItemWithTime < SimpleDelegator
      def updated_on
        Time.parse(super)
      end

      def ==(other)
        self.updated_on == other.updated_on
      end
    end

    class APIAsset < ItemWithTime
      REQUEST_OPTS = {
        open_timeout: 5,
        read_timeout: 5
      }

      def file
        @file ||= StringIO.new(fetch_data)
      end

      def ==(other)
        return super if digest.to_s == '' || other.digest.to_s == ''
        self.file_size == other.file_size && self.digest == other.digest
      end

      def fetch_data(attempt = 1)
        uri = URI.parse(rels[:file].href)
        opts = REQUEST_OPTS.merge({
          # verify_mode: OpenSSL::SSL::VERIFY_PEER # OpenSSL::SSL::VERIFY_NONE
          use_ssl: uri.port == 443
        })

        Net::HTTP.start(uri.host, uri.port, opts) do |http|
          resp = http.get(uri.path)
          raise "Invalid response: #{resp.code}" unless resp.code.to_i == 200
          resp.body
        end
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        raise if attempt > 3 # max attempts
        # puts "#{e.class} for #{File.basename(uri.path)}! Retrying request..."
        fetch_data(attempt + 1)
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
        check_errors!(tpl.delete_template) if tpl && tpl.can?(:delete_template)
      end

      def add_asset(file_name, file)
        check_errors! theme.create_theme_asset(
          file_name: file_name,
          data: file
        )
      end

      def remove_asset(file_name)
        asset = theme.assets.find{|t| t.file_name == file_name }
        check_errors!(asset.delete_theme_asset) if asset
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
