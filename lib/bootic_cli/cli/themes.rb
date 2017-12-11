require 'fileutils'
require 'open-uri'
require 'thread'
require 'listen'
require_relative './themes/theme_diff'

module BooticCli
  module Commands
    class Themes < BooticCli::Command
      desc 'pull [shop] [dir]', 'Pull latest theme changes in [shop] into directory [dir] (current by default)'
      option :destroy, banner: '<true|false>', default: 'true'
      def pull(subdomain = nil, dir = '.')
        logged_in_action do
          # if theme wasn't specified and no theme exists
          # then set clone/download location to subdomain name
          if subdomain and dir == '.' and !theme_exists?(dir)
            dir = subdomain
          end

          theme = current_theme(dir, subdomain)
          diff = ThemeDiff.new(dir, theme, true)
          check_dupes!(diff.local_assets)

          download_opts = {
            overwrite: false,
            interactive: true
          }

          assets_dir = File.join(dir, 'assets')
          FileUtils.mkdir_p assets_dir

          notice 'Updating local templates...'
          maybe_update(dir, diff.templates_updated_in_remote, 'remote', 'local') do |t, path|
            write_local(path, t.new_body)
          end

          if options['destroy'] == 'false'
            notice 'Not removing local files that were removed on remote.'
          else
            notice 'Removing local files that were removed on remote...'
            diff.local_templates_not_in_remote.each { |f| delete_file File.expand_path(f.path) }
            diff.local_assets_not_in_remote.each { |f| delete_file File.expand_path(f.path) }
          end

          notice 'Pulling missing files from remote...'
          download_templates(dir, theme.templates, download_opts)
          download_assets(assets_dir, theme.assets, download_opts)
        end
      end

      desc 'push [shop] [dir]', 'Push all local theme files in [dir] to remote shop [shop]'
      option :destroy, banner: '<true|false>', default: 'true'
      def push(subdomain = nil, dir = '.')
        logged_in_action do
          theme = current_theme(dir, subdomain)
          notice 'Pushing local changes to remote...'

          diff = ThemeDiff.new(dir, theme, true)
          check_dupes!(diff.local_assets)

          # update existing templates
          notice 'Updating remote templates...'
          maybe_update(dir, diff.templates_updated_locally, 'local', 'remote') do |t, path|
            upsert_template(theme, path)
          end

          notice 'Pushing files that are missing in remote...'
          diff.local_templates_not_in_remote.each { |f| upsert theme, File.expand_path(f.path) }
          diff.local_assets_not_in_remote.each { |f| upsert theme, File.expand_path(f.path) }

          if options['destroy'] == 'false'
            notice 'Not removing remote files that were removed locally.'
          else
            notice 'Removing remote files that were removed locally...'
            diff.remote_templates_not_in_dir.each { |f| delete theme, File.join(dir, f.file_name) }
            diff.remote_assets_not_in_dir.each { |f| delete theme, File.join(dir, 'assets', f.file_name) }
          end
        end
      end

      desc 'sync [shop] [dir]', 'Sync local theme copy in [dir] with remote [shop]'
      def sync(subdomain = nil, dir = '.')
        logged_in_action do
          theme = current_theme(dir, subdomain)
          notice 'Syncing local copy with remote...'

          diff = ThemeDiff.new(dir, theme)
          check_dupes!(diff.local_assets)

          download_opts = {
            overwrite: false,
            interactive: false
          }

          assets_dir = File.join(dir, 'assets')
          FileUtils.mkdir_p assets_dir

          # first, update existing templates in each side
          notice 'Updating local templates...'
          maybe_update(dir, diff.templates_updated_in_remote, 'remote', 'local') do |t, path|
            write_local(path, t.new_body)
          end

          notice 'Updating remote templates...'
          maybe_update(dir, diff.templates_updated_locally, 'local', 'remote') do |t, path|
            upsert_template(theme, path)
          end

          # now, download missing files on local end
          notice 'Downloading missing local templates & assets...'
          download_templates(dir, theme.templates, download_opts)
          download_assets(assets_dir, theme.assets, download_opts)

          # now, upload missing files on remote
          notice 'Uploading missing remote templates & assets...'
          diff.local_templates_not_in_remote.each { |f| upsert_template(theme, f.path) }
          diff.local_assets_not_in_remote.each { |f| upsert_asset(theme, f.path) }
        end
      end

      desc 'compare [shop] [dir]', 'Show differences between local and remote copies'
      def compare(subdomain = nil, dir = '.')
        logged_in_action do
          notice 'Comparing local and remote copies of theme...'
          theme = current_theme(dir, subdomain)
          diff = ThemeDiff.new(dir, theme)

          notice "Local <--- Remote"

          diff.templates_updated_in_remote.each do |t|
            puts "Updated in remote: #{t.file_name}"
          end

          diff.remote_templates_not_in_dir.each do |t|
            puts "Remote template not in local dir: #{t.file_name}"
          end

          diff.remote_assets_not_in_dir.each do |t|
            puts "Remote asset not in local dir: #{t.file_name}"
          end

          notice "Local ---> Remote"

          diff.templates_updated_locally.each do |t|
            puts "Updated locally: #{t.file_name}"
          end

          diff.local_templates_not_in_remote.each do |f|
            puts "Local template not in remote: #{f.file_name}"
          end

          diff.local_assets_not_in_remote.each do |f|
            puts "Local asset not in remote: #{f.file_name}"
          end
        end
      end

      desc 'watch [shop] [dir]', 'Watch theme directory at [dir] and create/update/delete the one in [shop] when changed'
      def watch(subdomain = nil, dir = '.')
        logged_in_action do
          theme = current_theme(dir, subdomain)

          unless File.exist?(File.join(dir, 'theme.yml'))
            input = ask("Couldn't find a theme.yml file in the #{dir} directory. Should we create one? [y]")
            unless ['', 'y'].include?(input.downcase)
              abort("Sure, no problem. You're the boss.")
            end

            write_theme_yaml(dir)
          end

          listener = Listen.to(dir) do |modified, added, removed|
            if modified.any?
              modified.each do |path|
                upsert theme, path
              end
            end

            if added.any?
              added.each do |path|
                upsert theme, path
              end
            end

            if removed.any?
              removed.each do |path|
                delete theme, path
              end
            end

            # update local cache
            theme = theme.self
          end

          notice "Watching #{File.expand_path(dir)} for changes..."
          listener.start

          # ctrl-c
          Signal.trap('INT') {
            listener.stop
            puts 'See you in another lifetime, brotha.'
            exit
          }

          sleep
        end
      end

      private

      def current_theme(dir, subdomain)
        @dirname   = dirname_for(dir)

        @found_shop = if subdomain
          get_shop(subdomain) or raise "Couldn't find shop with subdomain #{subdomain}"
        else
          theme_shop = read_theme_yaml(dir)[:shop]

          # unless subdomain is given, deduce the current shop from the theme.yml file
          # if none found, then use the dirname, and if still none, then fall back to shops.first
          get_shop(theme_shop || @dirname) || root.shops.first
        end

        check_subdomain!(@found_shop.subdomain, @dirname)
        @found_shop.theme
      end

      def current_shop
        @found_shop
      end

      def get_shop(subdomain = nil)
        shop = if subdomain
          if root.has?(:all_shops)
            root.all_shops(subdomains: subdomain).items.first
          else
            root.shops.select { |s| s.subdomain == subdomain }.first
          end
        else
          root.shops.first
        end
      end

      def check_subdomain!(subdomain, dirname)
        if dirname != subdomain
          input = ask("Shop #{highlight(subdomain)} doesn't match the current directory name: #{highlight(dirname)}. Is that OK? [y]")
          unless ['', 'y'].include?(input.downcase)
            abort 'Thought so.'
          end
        end
      end

      def dirname_for(dir)
        File.basename(File.expand_path(dir))
      end

      def check_dupes!(list)
        names = list.map { |f| f.file_name.downcase }
        dupes = names.group_by { |e| e }.select { |k, v| v.size > 1 }.map(&:first)

        dupes.each do |downcased|
          arr = list.select { |f| f.file_name.downcase == downcased }
          puts highlight(" --> Name clash between files: " + arr.map(&:file_name).join(', '), :red)
        end

        if dupes.any?
          puts highlight("Please ensure there are no name clashes before continuing. Thanks!")
          abort
        end
      end

      def theme_exists?(dir)
        File.exist?(File.join(dir, 'layout.html'))
      end

      def read_theme_yaml(dir)
        YAML.load_file(File.join(dir, 'theme.yml'))
      rescue Errno::ENOENT => e
        {}
      end

      def write_theme_yaml(dir)
        path = File.join(dir, 'theme.yml')
        obj  = { title: @found_shop.subdomain, description: 'Theme for #{@found_shop.subdomain}' }
        File.open(path, 'w') { |f| f.write(YAML.dump(obj)) }
      end

      def maybe_update(dir, modified_templates, source_name, target_name, &block)
        modified_templates.each do |t|
          puts "---------"
          puts "#{source_name} #{t.file_name} was modified at #{t.updated_on} (more recent than #{target_name}):"
          puts "---------"
          puts t.diff.to_s(:color)

          input = ask("\nUpdate #{target_name} #{t.file_name}? [y]")
          next unless input == '' or input.strip.downcase == 'y'

          yield(t, File.join(dir, t.file_name))
        end
      end

      def upsert(theme, path)
        if path =~ /assets/
          upsert_asset theme, path
        else
          upsert_template theme, path
        end
      end

      def delete_file(path)
        File.unlink path
        puts "Deleted local file: #{path}"
      end

      def delete(theme, path)
        if path =~ /assets/
          delete_asset theme, path
        else
          delete_template theme, path
        end
      end

      def delete_template(theme, path)
        fname = File.basename(path)
        tpl = theme.templates.find{|t| t.file_name == fname}
        return unless tpl

        if tpl.has?(:delete_template)
          puts "Deleting remote template: #{path}"
          tpl.delete_template
        else
          puts 'Template cannot be deleted. Re-fetching...'
          write_local(path, tpl.body)
        end
      end

      def delete_asset(theme, path)
        fname = File.basename(path)
        asset = theme.assets.find { |t| t.file_name == fname }
        return unless asset
        puts "Deleting remote asset: #{path}"
        asset.delete_theme_asset
      end

      def upsert_template(theme, path)
        confirm_upload(theme.create_template(
          file_name: File.basename(path),
          body: File.read(path)
        ), path)
      end

      def upsert_asset(theme, path)
        puts "Upserting asset: #{path}"
        confirm_upload(theme.create_theme_asset(
          file_name: File.basename(path),
          data: File.new(path)
        ), path)
      end

      def confirm_upload(entity, path)
        if entity.has?(:errors)
          puts "File has errors: #{File.basename(path)}"
          entity.errors.each do |e|
            puts [" --> ", e.field, e.messages.join(', ')].join(' ')
          end
        else
          puts "Uploaded file: #{File.basename(path)}"
        end
      end

      def download_templates(dir, templates, opts = {})
        templates.each do |t|
          path = File.join(dir, t.file_name)

          if File.exist?(path)
            next # our modified templates will take care of this

            # input = ask('Template exists: #{t.file_name}. Overwrite? [n]')
            # next if input == '' or input.strip.downcase == 'n'
          end
          write_local(path, t.body)
        end
      end

      def download_assets(dir, assets, opts = {})
        queue = Queue.new

        threads = assets.map do |a|
          path = File.join(dir, a.file_name)

          if File.exist?(path) && !opts[:overwrite]
            next unless opts[:interactive]
            input = ask("Asset exists: #{a.file_name}. Overwrite? [n]")
            next if input == '' or input.strip.downcase == 'n'
          end

          Thread.new do
            file = open(a.rels[:file].href)
            queue << write_local(path, file.read, 'wb')
          end
        end.compact

        printer = Thread.new do
          while path = queue.pop
            puts path
          end
        end

        threads.map &:join
        queue << false
        printer.join
      end

      def has_dos_line_endings?(path)
        !!IO.read(path)["\r\n"]
      end

      def write_local(path, content, mode = 'w')
        if mode == 'w'
          # remove DOS line endings for new templates
          # or for existing ones that don't have any.
          if !File.exist?(path) or !has_dos_line_endings?(path)
            content = StringUtils.normalize_endings(content)
          end
        end

        File.open(path, mode) do |io|
          io.write(content)
        end

        puts "Wrote #{File.basename(path)}"
        path
      end

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

      def notice(str)
        parts = [" --->", str]
        parts.insert(1, "[#{@dirname}]") if @dirname
        puts highlight(parts.join(" "), :bold)
      end

      def highlight(str, color = :bold)
        ["\033[", COLORS[color], 'm', str, "\033[0m"].join('')
      end

      declare self, 'manage shop themes'
    end
  end
end
