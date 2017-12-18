require 'yaml/store'
require 'bootic_cli/themes/api_theme'
require 'bootic_cli/themes/fs_theme'

module BooticCli
  module Themes
    class ThemeSelector
      def self.select_theme_pair(subdomain, dir, root, prompt:)
        new(root, prompt: prompt).select_theme_pair(subdomain, dir)
      end

      def initialize(root, prompt:)
        @root = root
        @prompt = prompt
      end

      def select_theme_pair(subdomain, dir)
        local_theme = FSTheme.new(File.expand_path(dir))
        st = YAML::Store.new(File.join(File.expand_path(dir), '.state'))
        st.transaction do
          sub = st['subdomain']
          if sub
            shop = find_remote_shop(sub)
            raise "No shop could be resolved with subdomain: #{subdomain} and dir: #{dir}" unless shop
            remote_theme = resolve_remote_theme(shop)
            prompt.say "Preview remote theme at #{remote_theme.rels[:theme_preview].href}", :yellow
            [local_theme, APITheme.new(remote_theme)]
          else # no subdomain stored yet. Resolve and store.
            shop = resolve_shop(subdomain, dir)
            st['subdomain'] = shop.subdomain
            remote_theme = resolve_remote_theme(shop)
            prompt.say "Preview remote theme at #{remote_theme.rels[:theme_preview].href}", :yellow
            [local_theme, APITheme.new(remote_theme)]
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
        shop = if subdomain
          find_remote_shop(subdomain)
        elsif dir
          subdomain = File.basename(dir)
          find_remote_shop(subdomain)
        end
        shop || root.shops.first
      end

      def resolve_remote_theme(shop)
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
