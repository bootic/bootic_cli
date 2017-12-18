require 'yaml/store'
require 'bootic_cli/themes/api_theme'
require 'bootic_cli/themes/fs_theme'

module BooticCli
  module Themes
    class ThemeSelector
      def initialize(root, prompt:)
        @root = root
        @prompt = prompt
      end

      def select_theme_pair(subdomain, dir, production = false)
        local_theme = select_local_theme(dir)
        st = YAML::Store.new(File.join(File.expand_path(dir), '.state'))
        shop = resolve_and_store_shop(subdomain, dir)
        remote_theme = resolve_remote_theme(shop, production)
        prompt.say "Preview remote theme at #{remote_theme.rels[:theme_preview].href}", :yellow
        [local_theme, APITheme.new(remote_theme)]
      end

      def select_local_theme(dir)
        FSTheme.new(File.expand_path(dir))
      end

      def resolve_and_store_shop(subdomain, dir)
        st = YAML::Store.new(File.join(File.expand_path(dir), '.state'))
        st.transaction do
          sub = st['subdomain']
          if sub
            shop = find_remote_shop(sub)
            raise "No shop could be resolved with subdomain: #{subdomain} and dir: #{dir}" unless shop
            shop
          else # no subdomain stored yet. Resolve and store.
            shop = resolve_shop_from_subdomain_or_dir(subdomain, dir)
            st['subdomain'] = shop.subdomain
            shop
          end
        end
      end

      private

      def find_remote_shop(subdomain)
        if root.has?(:all_shops)
          root.all_shops(subdomains: subdomain).first
        else
          root.shops.find { |s| s.subdomain == subdomain }
        end
      end

      def resolve_shop_from_subdomain_or_dir(subdomain, dir)
        shop = if subdomain
          find_remote_shop(subdomain)
        elsif dir
          subdomain = File.basename(dir)
          find_remote_shop(subdomain)
        end
        shop || root.shops.first
      end

      def resolve_remote_theme(shop, production = false)
        if production
          prompt.say "Working on production theme", :red
          return shop.theme
        end

        prompt.say "Working on development theme", :green
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
      attr_reader :root, :prompt, :production
    end
  end
end
