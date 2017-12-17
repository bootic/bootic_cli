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
        COLORS = {
          black:        '30',
          dark_gray:    '1;30',
          red:          '31',
          light_red:    '1;31',
          green:        '32',
          light_green:  '1;32',
          brown:        '33',
          yellow:       '1;33',
          blue:         '34',
          light_blue:   '1;34',
          purple:       '35',
          light_purple: '1;35',
          cyan:         '36',
          light_cyan:   '1;36',
          light_gray:   '37',
          white:        '1;37',
          bold:         '1',
          gray:         '90'
        }

        def initialize
          @shell = Thor::Shell::Basic.new
        end

        def yes_or_no?(question, default_answer)
          default_char = default_answer ? 'y' : 'n'
          input = shell.ask("\n#{question} [#{default_char}]").strip
          input == '' || input.downcase == default_char
        end

        def notice(str)
          parts = [" --->", str]
          parts.insert(1, "[#{@dirname}]") if @dirname
          puts highlight(parts.join(" "), :bold)
        end

        def highlight(str, color = :bold)
          ["\033[", COLORS[color], 'm', str, "\033[0m"].join('')
        end

        def puts(str)
          shell.say str
        end

        private
        attr_reader :shell
      end

      declare self, 'manage shop themes'
    end
  end
end
