require 'bootic_cli/themes/api_theme'
require 'bootic_cli/themes/fs_theme'

module BooticCli
  module Themes
    class ThemeSelector
      def initialize(root, prompt:)
        @root = root
        @prompt = prompt
      end

      def setup_theme_pair(subdomain, dir = nil, production = false)
        shop = find_remote_shop(subdomain)
        raise "No shop with subdomain #{subdomain}" unless shop

        path = dir || shop.subdomain
        local_theme = select_local_theme(path, shop.subdomain)
        remote_theme = select_remote_theme(shop, production)

        prompt.say "Cloning theme files into #{local_theme.path}"
        prompt.say "Preview this theme at #{remote_theme.path}", :magenta
        [local_theme, remote_theme]
      end

      def select_theme_pair(subdomain, dir, production = false)
        local_theme = select_local_theme(dir)
        shop = find_remote_shop(local_theme.subdomain)
        raise "No shop with subdomain #{local_theme.subdomain}" unless shop
        remote_theme = select_remote_theme(shop, production)

        prompt.say "Preview this theme at #{remote_theme.path}", :magenta
        [local_theme, remote_theme]
      end

      def pair(subdomain, dir)
        shop = find_remote_shop(subdomain)
        raise "No shop with subdomain #{subdomain}" unless shop
        select_local_theme(dir, subdomain)
      end

      def select_local_theme(dir, subdomain = nil)
        FSTheme.new(File.expand_path(dir), subdomain: subdomain)
      end

      def select_remote_theme(shop, production = false)
        theme = resolve_remote_theme(shop, production)
        APITheme.new(theme)
      end

      def find_remote_shop(subdomain = nil)
        if !subdomain
          return root.shops.first
        end

        if root.has?(:all_shops)
          root.all_shops(subdomains: subdomain).first
        else
          root.shops.find { |s| s.subdomain == subdomain }
        end
      end

      private

      def resolve_remote_theme(shop, production = false)
        if production
          prompt.say "Working on public theme of shop #{shop.subdomain}", :red
          return shop.theme
        end

        prompt.say "Working on development theme of shop #{shop.subdomain}", :green
        themes = shop.themes
        if themes.has?(:dev_theme)
          themes.dev_theme
        elsif themes.can?(:create_dev_theme)
          prompt.say "Creating development theme...", :green
          themes.create_dev_theme
        else
          raise "No dev theme available"
        end
      end

      private
      attr_reader :root, :prompt
    end
  end
end
