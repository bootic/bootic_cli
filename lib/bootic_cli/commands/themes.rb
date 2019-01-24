# -*- encoding: utf-8 -*-
require 'launchy'
require 'bootic_cli/themes/theme_diff'
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
      option :shop, banner: '<shop_subdomain>', aliases: '-s', type: :string
      option :public, banner: '<true|false>', type: :boolean, aliases: '-p', desc: 'Clones public theme, even if dev theme exists'
      option :dev, banner: '<true|false>', type: :boolean, aliases: '-d', desc: 'Clones development theme, or creates one if missing'
      def clone(dir = nil)
        logged_in_action do
          local_theme, remote_theme = theme_selector.setup_theme_pair(options['shop'], dir, options['public'], options['dev'])

          if File.exist?(local_theme.path)
            prompt.say "Directory already exists! (#{local_theme.path})", :red
          else
            prompt.say "Cloning theme files into #{local_theme.path}"
            workflows.pull(local_theme, remote_theme)
            local_theme.write_subdomain
          end
        end
      end

      desc 'dev', 'Create a development theme for your current shop'
      def dev
        within_theme do
          local_theme, remote_theme = theme_selector.select_theme_pair(default_subdomain, current_dir)
          unless remote_theme.public?
            prompt.say "You already have a development theme set up!", :red
            abort
          end

          local_theme = theme_selector.create_dev_theme(current_dir)
          prompt.say "Success! You're now working on a development copy of your theme."
          prompt.say "Any changes you push or sync won't appear on your public website, but on the development version."
          prompt.say "Once you're ready to merge your changes back, run the `publish` command."
        end
      end

      desc 'pull', 'Pull remote changes into current theme directory'
      option :public, banner: '<true|false>', type: :boolean, aliases: '-p', desc: 'Pull from public theme, even if dev theme exists'
      option :delete, banner: '<true|false>', type: :boolean, desc: 'Remove local files that were removed in remote theme (default: true)'
      def pull
        within_theme do
          local_theme, remote_theme = theme_selector.select_theme_pair(default_subdomain, current_dir, options['public'])
          workflows.pull(local_theme, remote_theme, delete: options['delete'] || true)
          prompt.say "Done! Preview this theme at #{remote_theme.path}", :cyan
        end
      end

      desc 'push', 'Push all local theme files in current dir to remote shop'
      option :public, banner: '<true|false>', type: :boolean, aliases: '-p', desc: 'Push to public theme, even if dev theme exists'
      option :delete, banner: '<true|false>', type: :boolean, desc: 'Remove files in remote theme that were removed locally (default: true)'
      def push
        within_theme do
          local_theme, remote_theme = theme_selector.select_theme_pair(default_subdomain, current_dir, options['public'])
          warn_about_public if remote_theme.public? and options['public'].nil?
          workflows.push(local_theme, remote_theme, delete: options['delete'] || true)
          prompt.say "Done! View updated version at #{remote_theme.path}", :cyan
        end
      end

      desc 'sync', 'Sync changes between local and remote themes'
      option :public, banner: '<true|false>', type: :boolean, aliases: '-p', desc: 'Sync to public theme, even if dev theme exists'
      def sync
        within_theme do
          local_theme, remote_theme = theme_selector.select_theme_pair(default_subdomain, current_dir, options['public'])
          warn_about_public if remote_theme.public? and options['public'].nil?
          workflows.sync(local_theme, remote_theme)
          prompt.say "Synced! Preview this theme at #{remote_theme.path}", :cyan
        end
      end

      desc 'compare', 'Show differences between local and remote copies (both public and dev, if present)'
      def compare
        within_theme do
          local_theme, remote_theme = theme_selector.select_theme_pair(default_subdomain, current_dir)
          workflows.compare(local_theme, remote_theme)

          # if we just compared against the dev theme, redo the mumbo-jumbo but with the public one
          unless remote_theme.public?
            local_theme, public_theme = theme_selector.select_theme_pair(default_subdomain, current_dir, true)
            workflows.compare(local_theme, public_theme)
          end
        end
      end

      desc 'watch', 'Watch local theme dir and update remote when any file changes'
      option :public, banner: '<true|false>', type: :boolean, aliases: '-p', desc: 'Pushes any changes to public theme, even if dev theme exists'
      def watch
        within_theme do
          local_theme, remote_theme = theme_selector.select_theme_pair(default_subdomain, current_dir, options['public'])
          warn_about_public if remote_theme.public? and options['public'].nil?

          diff = BooticCli::Themes::ThemeDiff.new(source: local_theme, target: remote_theme)
          if diff.any?
            if prompt.yes_or_no?("There are differences between the remote theme and your local copy. Sync now?", true)
              workflows.sync(local_theme, remote_theme)
              prompt.say "Synced!", :cyan
            end
          end

          workflows.watch(current_dir, remote_theme)
        end
      end

      desc 'publish', 'Merges your development theme back into your public website'
      def publish
        within_theme do
          local_theme, remote_theme = theme_selector.select_theme_pair(default_subdomain, current_dir)

          if remote_theme.public?
            prompt.say "You don't seem to have a development theme set up, so there's nothing to publish. :)", :red
            prompt.say "To push your local changes directly to your public theme, either run the `push` or `sync` commands.", :red
          else

            # check if there are any differences between the dev and public themes
            local_theme, public_theme = theme_selector.select_theme_pair(default_subdomain, current_dir, true)
            diff = BooticCli::Themes::ThemeDiff.new(source: remote_theme, target: public_theme)

            unless diff.any?
              unless prompt.yes_or_no?("Your public and development themes seem to be in sync (no differences). Publish anyway?", false)
                prompt.say "Okeysay. Bye."
                exit 1
              end
            end

            # prompt.say("Publishing means all your public theme's templates and assets will be replaced and lost.")
            if prompt.yes_or_no?("Would you like to make a local copy of your current public theme before publishing?", diff.any?) # default to true if changes exist
              backup_path = File.join(local_theme.path, "public-theme-backup-#{Time.now.to_i}")
              backup_theme = theme_selector.select_local_theme(backup_path, local_theme.subdomain)

              prompt.say("Gotcha. Backing up your public theme into #{prompt.highlight(backup_theme.path)}")
              workflows.pull(backup_theme, public_theme)
              prompt.say "Done! Existing public theme was saved to #{prompt.highlight(File.basename(backup_theme.path))}", :cyan
            end

            workflows.publish(local_theme, remote_theme)
          end
        end
      end

      desc 'open', 'Open theme preview URL in a browser'
      option :public, banner: '<true|false>', type: :boolean, aliases: '-p', desc: 'Opens public theme URL'
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

      def warn_about_public
        unless prompt.yes_or_no?("You're pushing changes directly to your public theme. Are you sure?", true)
          prompt.say("Ok, sure. You can skip the above warning prompt by passing a `--public` flag.")
          abort
        end
      end

      def within_theme(&block)
        unless is_within_theme?
          prompt.say "This directory doesn't look like a Bootic theme! (#{current_expanded_dir})", :magenta
          abort
        end

        logged_in_action do
          yield
        end
      end

      def is_within_theme?
        File.exist?(File.join(current_expanded_dir, 'layout.html'))
      end

      def current_dir
        '.'
      end

      def current_expanded_dir
        File.expand_path(current_dir)
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

          begin
            input = shell.ask("#{question} [#{default_char}]").strip
          rescue Interrupt
            say "\nCtrl-C received. Bailing out!", :magenta
            abort
          end

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
