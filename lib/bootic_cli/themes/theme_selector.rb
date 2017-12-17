require 'yaml/store'
require 'bootic_cli/themes/api_theme'
require 'bootic_cli/themes/fs_theme'

module BooticCli
  module Themes
    class ThemeSelector
      def self.select_theme_pair(subdomain, dir, root)
        new(root).select_theme_pair(subdomain, dir)
      end

      def initialize(root)
        @root = root
      end

      def select_theme_pair(subdomain, dir)
        local_theme = FSTheme.new(File.expand_path(dir))
        st = YAML::Store.new(File.join(File.expand_path(dir), '.state'))
        st.transaction do
          sub = st['subdomain']
          if sub
            shop = find_remote_shop(sub)
            raise "No shop could be resolved with subdomain: #{subdomain} and dir: #{dir}" unless shop
            [local_theme, APITheme.new(shop.theme)]
          else # no subdomain stored yet. Resolve and store.
            shop = resolve_shop(subdomain, dir)
            st['subdomain'] = shop.subdomain
            [local_theme, APITheme.new(shop.theme)]
          end
        end
      end

      def find_remote_shop(subdomain)
        if root.has?(:all_shops)
          root.all_shops(subdomains: subdomain).first
        else
          root.shops.find { |s| s.subdomain == subdomain }
        end
      end

      def resolve_shop(subdomain, dir)
        if subdomain
          if root.has?(:all_shops)
            root.all_shops(subdomains: subdomain).first
          else
            root.shops.find { |s| s.subdomain == subdomain }
          end
        elsif dir
          subdomain = File.basename(dir)
          resolve_shop subdomain, dir
        else
          root.shops.first
        end
      end

      private
      attr_reader :root
    end
  end
end
