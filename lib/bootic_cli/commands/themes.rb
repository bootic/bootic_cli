require 'bootic_cli/themes/workflows'
require 'bootic_cli/themes/theme_selector'

module BooticCli
  module Commands
    class Themes < BooticCli::Command
      desc 'pull [shop] [dir]', 'Pull latest theme changes in [shop] into directory [dir] (current by default)'
      option :destroy, banner: '<true|false>', default: 'true'
      def pull(subdomain = nil, dir = '.')
        logged_in_action do
          local_theme, remote_theme = select_theme_pair(subdomain, dir)
          workflows.pull(local_theme, remote_theme, destroy: options['destroy'] == 'true')
        end
      end

      desc 'push [shop] [dir]', 'Push all local theme files in [dir] to remote shop [shop]'
      option :destroy, banner: '<true|false>', default: 'true'
      def push(subdomain = nil, dir = '.')
        logged_in_action do
          local_theme, remote_theme = select_theme_pair(subdomain, dir)
          workflows.push(local_theme, remote_theme, destroy: options['destroy'] == 'true')
        end
      end

      desc 'sync [shop] [dir]', 'Sync local theme copy in [dir] with remote [shop]'
      def sync(subdomain = nil, dir = '.')
        logged_in_action do
          local_theme, remote_theme = select_theme_pair(subdomain, dir)
          workflows.sync(local_theme, remote_theme)
        end
      end

      desc 'compare [shop] [dir]', 'Show differences between local and remote copies'
      def compare(subdomain = nil, dir = '.')
        logged_in_action do
          local_theme, remote_theme = select_theme_pair(subdomain, dir)
          workflows.compare(local_theme, remote_theme)
        end
      end

      desc 'watch [shop] [dir]', 'Watch theme directory at [dir] and create/update/delete the one in [shop] when changed'
      def watch(subdomain = nil, dir = '.')
        logged_in_action do
          _, remote_theme = select_theme_pair(subdomain, dir)
          workflows.watch(dir, remote_theme)
        end
      end

      private

      def workflows
        BooticCli::Themes::Workflows.new(prompt: Prompt.new)
      end

      def select_theme_pair(subdomain, dir)
        BooticCli::Themes::ThemeSelector.select_theme_pair(subdomain, dir, root)
      end

      class Prompt
        def initialize(shell = Thor::Shell::Color.new)
          @shell = shell
        end

        def yes_or_no?(question, default_answer)
          default_char = default_answer ? 'y' : 'n'
          input = shell.ask("\n#{question} [#{default_char}]").strip
          return default_answer if input == '' || input.downcase == default_char
          !default_answer
        end

        def notice(str)
          parts = [" --->", str]
          highlight parts.join(' ')
        end

        def highlight(str, color = :bold)
          say str, color
        end

        def say(str, color = nil)
          shell.say str, color
        end

        private
        attr_reader :shell
      end

      declare self, 'manage shop themes'
    end
  end
end
