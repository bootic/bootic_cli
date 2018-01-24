require 'bootic_cli/themes/api_theme'
require 'bootic_cli/themes/fs_theme'

module BooticCli
  module Themes
    class ThemeSelector
      def initialize(root, prompt:)
        @root = root
        @prompt = prompt
      end

      def setup_theme_pair(subdomain, dir = nil, wants_public = false, wants_dev = false)
        raise "Cannot pass both public and dev flags at the same time!" if wants_public && wants_dev

        shop = find_remote_shop(subdomain)
        raise "No shop with subdomain #{subdomain}" unless shop

        path = dir || shop.subdomain
        local_theme  = select_local_theme(path, shop.subdomain)
        remote_theme = select_remote_theme(shop, wants_public)

        # if no `wants_public` flag was passed and no dev theme is present
        # ask the user whether he/she wants to create one now.
        if !wants_public and remote_theme.public?
          raise 'Dev theme not available!' unless shop.themes.can?(:create_dev_theme)

          if wants_dev or prompt.yes_or_no?("Would you like to create (and work on) a development version of your theme? (recommended)", true)
            prompt.say "Good thinking. Creating a development theme out of your current public one...", :green
            remote_theme = shop.themes.create_dev_theme
          end
        end

        [local_theme, remote_theme]
      end

      def select_theme_pair(subdomain, dir, production = false)
        local_theme = select_local_theme(dir)
        shop = find_remote_shop(local_theme.subdomain)
        raise "No shop with subdomain #{local_theme.subdomain}" unless shop
        remote_theme = select_remote_theme(shop, production)
        [local_theme, remote_theme]
      end

      def pair(subdomain, dir)
        shop = find_remote_shop(subdomain)
        raise "No shop with subdomain #{subdomain}" unless shop
        theme = select_local_theme(dir, subdomain)
        theme.write_subdomain
        theme
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
        if production or !shop.themes.has?(:dev_theme)
          prompt.say "Working on public theme of shop #{shop.subdomain}", :yellow
          shop.theme
        else
          prompt.say "Working on development theme of shop #{shop.subdomain}", :green
          shop.themes.dev_theme
        end
      end

      attr_reader :root, :prompt
    end
  end
end
