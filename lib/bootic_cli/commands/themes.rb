require 'launchy'
require 'bootic_cli/themes/workflows'
require 'bootic_cli/themes/theme_selector'

module BooticCli
  module Commands
    class Themes < BooticCli::Command

      # def examples
      #   say "Note: By [shop] we always mean the shop's subdomain. For example:"
      #   say "bootic themes clone dir --shop=foobar (assuming my shop runs at foobar.bootic.net)"
      # end

      desc 'clone [dir]', 'Clone remote theme into directory [dir]'
      option :shop, banner: '<shop_subdomain>', type: :string
      option :destroy, banner: '<true|false>', type: :boolean, default: true
      option :public, banner: '<true|false>', type: :boolean, default: false, aliases: '-p'
      option :dev, banner: '<true|false>', type: :boolean, default: false, aliases: '-d'
      def clone(dir = nil)
        logged_in_action do
          local_theme, remote_theme = theme_selector.setup_theme_pair(options['shop'], dir, options['public'], options['dev'])
          workflows.pull(local_theme, remote_theme, destroy: options['destroy'])
        end
      end

      desc 'pull', 'Pull remote changes into current theme directory'
      option :public, banner: '<true|false>', type: :boolean, default: false, aliases: '-p'
      option :destroy, banner: '<true|false>', type: :boolean, default: true
      def pull
        within_theme do
          local_theme, remote_theme = theme_selector.select_theme_pair(default_subdomain, current_dir, options['public'])
          workflows.pull(local_theme, remote_theme, destroy: options['destroy'])
        end
      end

      desc 'push', 'Push all local theme files in current dir to remote shop'
      option :public, banner: '<true|false>', type: :boolean, default: false, aliases: '-p'
      option :destroy, banner: '<true|false>', type: :boolean, default: true
      def push
        within_theme do
          local_theme, remote_theme = theme_selector.select_theme_pair(default_subdomain, current_dir, options['public'])
          workflows.push(local_theme, remote_theme, destroy: options['destroy'])
        end
      end

      desc 'sync', 'Sync local theme copy in local dir with remote shop'
      option :public, banner: '<true|false>', type: :boolean, default: false, aliases: '-p'
      def sync
        within_theme do
          local_theme, remote_theme = theme_selector.select_theme_pair(default_subdomain, current_dir, options['public'])
          workflows.sync(local_theme, remote_theme)
        end
      end

      desc 'compare', 'Show differences between local and remote copies'
      option :public, banner: '<true|false>', type: :boolean, default: false, aliases: '-p'
      def compare
        within_theme do
          local_theme, remote_theme = theme_selector.select_theme_pair(default_subdomain, current_dir, options['public'])
          workflows.compare(local_theme, remote_theme)
        end
      end

      desc 'watch', 'Watch local theme directory and create/update/delete remote one when any file changes'
      option :public, banner: '<true|false>', type: :boolean, default: false, aliases: '-p'
      def watch
        within_theme do
          _, remote_theme = theme_selector.select_theme_pair(default_subdomain, current_dir, options['public'])
          workflows.watch(current_dir, remote_theme)
        end
      end

      desc 'publish', 'Publish local files to remote public theme'
      def publish
        within_theme do
          local_theme, remote_theme = theme_selector.select_theme_pair(default_subdomain, current_dir, false)
          workflows.publish(local_theme, remote_theme)
        end
      end

      desc 'open', 'Open theme preview URL in a browser'
      option :public, banner: '<true|false>', type: :boolean, default: false, aliases: '-p'
      def open
        within_theme do
          _, remote_theme = theme_selector.select_theme_pair(default_subdomain, current_dir, options['public'])
          Launchy.open remote_theme.path
        end
      end

      desc 'pair', 'Pair this directory to remote [shop]'
      option :shop, banner: '<shop_subdomain>', type: :string, required: true
      def pair
        within_theme do
          local_theme = theme_selector.pair(options['shop'], current_dir)
          prompt.say "Directory #{local_theme.path} paired with shop #{options['shop']}", :green
        end
      end

      private

      def within_theme(&block)
        dir = File.expand_path(current_dir)
        unless File.exist?(File.join(dir, 'layout.html'))
          prompt.say "This directory doesn't look like a Bootic theme! (#{dir})", :magenta
          abort
        end

        logged_in_action do
          yield
        end
      end

      def current_dir
        '.'
      end

      def default_subdomain
        nil
      end

      def prompt
        @prompt ||= Prompt.new
      end

      def workflows
        BooticCli::Themes::Workflows.new(prompt: prompt)
      end

      def theme_selector
        @theme_selector ||= BooticCli::Themes::ThemeSelector.new(root, prompt: prompt)
      end

      class Prompt
        def initialize(shell = Thor::Shell::Color.new)
          @shell = shell
        end

        def yes_or_no?(question, default_answer)
          default_char = default_answer ? 'y' : 'n'
          input = shell.ask("#{question} [#{default_char}]").strip
          return default_answer if input == '' || input.downcase == default_char
          !default_answer
        end

        def notice(str)
          parts = [" --->", str]
          puts highlight parts.join(' ')
        end

        def say(str, color = nil)
          shell.say str, color
        end

        def highlight(str, color = :bold)
          shell.set_color str, color
        end

        private
        attr_reader :shell
      end

      declare self, 'Manage shop themes'
    end
  end
end
