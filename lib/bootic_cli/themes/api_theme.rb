require 'time'
require 'net/http'

module BooticCli
  module Themes
    class ItemWithTime < SimpleDelegator
      def updated_on
        Time.parse(super)
      end

      def ==(other)
        # puts "Comparing with time #{self.updated_on} vs #{other.updated_on}"
        self.updated_on.to_i == other.updated_on.to_i
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
        if digest.to_s == '' || other.digest.to_s == ''
          # puts "One or the other digest is empty: #{digest} -- #{other.digest}"
          return super
        end

        # file sizes may differ as they are served by CDN (that shrinks them)
        self.digest == other.digest # && self.file_size == other.file_size
      end

      def fetch_data(attempt = 1, skip_verify = false)
        uri = URI.parse(rels[:file].href)
        opts = REQUEST_OPTS.merge({
          verify_mode: skip_verify ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER,
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
      rescue OpenSSL::SSL::SSLError => e
        # retry but skipping verification
        fetch_data(attempt + 1, true)
      end
    end

    class APITheme

      class InvalidRequest < StandardError;
      class EntityTooLargeError < InvalidRequest; end
      class UnknownResponse < InvalidRequest;

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

      def delete!
        if theme.can?(:delete_theme)
          res = theme.delete_theme
          return res.status <= 204
        end
        false
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
        params = {
          file_name: file_name,
          body: body
        }

        if ts = get_updated_on(file_name)
          params.merge!(last_updated_on: ts.to_i)
        end

        check_errors!(theme.create_template(params)).tap do |entity|
          template_updated(file_name, entity)
        end
      end

      def remove_template(file_name)
        tpl = theme.templates.find { |t| t.file_name == file_name }
        if tpl && tpl.can?(:delete_template)
          res = tpl.delete_template
          res.status.to_i < 300
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
          res.status.to_i < 300
        else
          puts "Cannot delete asset: #{file_name}"
        end
      end

      private
      attr_reader :theme

      def get_updated_on(file_name)
        if tpl = templates.find { |t| t.file_name == file_name }
          tpl.updated_on
        end
      end

      def template_updated(file_name, new_template)
        if index = templates.index { |t| t.file_name == file_name }
          templates[index] = ItemWithTime.new(new_template)
        end
      end

      def check_errors!(entity)
        if !entity.respond_to?(:has)
          if entity.body['Request Entity Too Large']
            raise EntityTooLargeError.new("Request Entity Too Large")
          else
            raise UnknownResponse.new(entity.body)
          end
        elsif entity.has?(:errors)
          raise EntityErrors.new(entity.errors)
        end

        entity
      end
    end
  end
end
