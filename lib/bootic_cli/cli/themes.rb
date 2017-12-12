require 'fileutils'
require 'thread'
require 'listen'
require_relative './themes/theme_diff'
require_relative './themes/api_theme'
require_relative './themes/fs_theme'

module BooticCli
  module Commands
    class Themes < BooticCli::Command
      ASSETS_DIR = 'assets'

      desc 'pull [shop] [dir]', 'Pull latest theme changes in [shop] into directory [dir] (current by default)'
      option :destroy, banner: '<true|false>', default: 'true'
      def pull(subdomain = nil, dir = '.')
        logged_in_action do
          local_theme, remote_theme = select_theme_pair(subdomain, dir)
          diff = ThemeDiff.new(source: local_theme, target: remote_theme, force_update: true)
          check_dupes!(local_theme.assets)

          download_opts = {
            overwrite: false,
            interactive: true
          }

          notice 'Updating local templates...'
          maybe_update(diff.templates_updated_in_target, 'remote', 'local') do |t|
            local_theme.add_template t.file_name, t.body
          end

          if options['destroy'] == 'false'
            notice 'Not removing local files that were removed on remote.'
          else
            notice 'Removing local files that were removed on remote...'
            diff.source_templates_not_in_target.each { |f| local_theme.remove_template(f.file_name) }
            diff.source_assets_not_in_target.each { |f| local_theme.remove_asset(f.file_name) }
          end

          notice 'Pulling missing files from remote...'
          copy_templates(remote_theme, local_theme, download_opts)
          copy_assets(remote_theme, local_theme, download_opts)
        end
      end

      desc 'push [shop] [dir]', 'Push all local theme files in [dir] to remote shop [shop]'
      option :destroy, banner: '<true|false>', default: 'true'
      def push(subdomain = nil, dir = '.')
        logged_in_action do
          local_theme, remote_theme = select_theme_pair(subdomain, dir)
          diff = ThemeDiff.new(source: local_theme, target: remote_theme, force_update: true)
          check_dupes!(local_theme.assets)

          notice 'Pushing local changes to remote...'

          # update existing templates
          notice 'Updating remote templates...'
          maybe_update(diff.templates_updated_in_source, 'local', 'remote') do |t|
            remote_theme.add_template t.file_name, t.body
          end

          notice 'Pushing files that are missing in remote...'
          diff.source_templates_not_in_target.each { |f| remote_theme.add_template(f.file_name, f.body) }
          diff.source_assets_not_in_target.each { |f| remote_theme.add_asset(f.file_name, f.file) }

          if options['destroy'] == 'false'
            notice 'Not removing remote files that were removed locally.'
          else
            notice 'Removing remote files that were removed locally...'
            diff.target_templates_not_in_source.each { |f| remote_theme.remove_template(f.file_name) }
            diff.target_assets_not_in_source.each { |f| remote_theme.remove_asset(f.file_name) }
          end
        end
      end

      desc 'sync [shop] [dir]', 'Sync local theme copy in [dir] with remote [shop]'
      def sync(subdomain = nil, dir = '.')
        logged_in_action do
          local_theme, remote_theme = select_theme_pair(subdomain, dir)
          diff = ThemeDiff.new(source: local_theme, target: remote_theme, force_update: true)
          check_dupes!(local_theme.assets)
          notice 'Syncing local copy with remote...'

          download_opts = {
            overwrite: false,
            interactive: false
          }

          # first, update existing templates in each side
          notice 'Updating local templates...'
          maybe_update(diff.templates_updated_in_target, 'remote', 'local') do |t|
            local_theme.add_template t.file_name, t.body
          end

          notice 'Updating remote templates...'
          maybe_update(diff.templates_updated_in_source, 'local', 'remote') do |t|
            remote_theme.add_template t.file_name, t.body
          end

          # now, download missing files on local end
          notice 'Downloading missing local templates & assets...'
          copy_templates(remote_theme, local_theme, download_opts)
          copy_assets(remote_theme, local_theme, download_opts)

          # now, upload missing files on remote
          notice 'Uploading missing remote templates & assets...'
          diff.source_templates_not_in_target.each { |f| remote_theme.add_template(f.file_name, f.body) }
          diff.source_assets_not_in_target.each { |f| remote_theme.add_asset(f.file_name, f.file) }
        end
      end

      desc 'compare [shop] [dir]', 'Show differences between local and remote copies'
      def compare(subdomain = nil, dir = '.')
        logged_in_action do
          local_theme, remote_theme = select_theme_pair(subdomain, dir)
          diff = ThemeDiff.new(source: local_theme, target: remote_theme, force_update: false)
          notice 'Comparing local and remote copies of theme...'

          notice "Local <--- Remote"

          diff.templates_updated_in_target.each do |t|
            puts "Updated in remote: #{t.file_name}"
          end

          diff.target_templates_not_in_source.each do |t|
            puts "Remote template not in local dir: #{t.file_name}"
          end

          diff.target_assets_not_in_source.each do |t|
            puts "Remote asset not in local dir: #{t.file_name}"
          end

          notice "Local ---> Remote"

          diff.templates_updated_in_source.each do |t|
            puts "Updated locally: #{t.file_name}"
          end

          diff.source_templates_not_in_target.each do |f|
            puts "Local template not in remote: #{f.file_name}"
          end

          diff.source_assets_not_in_target.each do |f|
            puts "Local asset not in remote: #{f.file_name}"
          end
        end
      end

      desc 'watch [shop] [dir]', 'Watch theme directory at [dir] and create/update/delete the one in [shop] when changed'
      def watch(subdomain = nil, dir = '.')
        logged_in_action do
          _, remote_theme = select_theme_pair(subdomain, dir)

          listener = Listen.to(dir) do |modified, added, removed|
            if modified.any?
              modified.each do |path|
                upsert remote_theme, path
              end
            end

            if added.any?
              added.each do |path|
                upsert remote_theme, path
              end
            end

            if removed.any?
              removed.each do |path|
                delete remote_theme, path
              end
            end

            # update local cache
            remote_theme.reload!
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

      def select_theme_pair(subdomain, dir)
        shop = select_shop(subdomain)
        local_theme = select_local_theme(shop.subdomain, dir)
        remote_theme = select_remote_theme(shop)
        [local_theme, remote_theme]
      end

      def select_shop(subdomain)
        if subdomain
          if root.has?(:all_shops)
            root.all_shops(subdomains: subdomain).first
          else
            root.shops.find { |s| s.subdomain == subdomain }
          end
        else
          root.shops.first
        end
      end

      def select_local_theme(subdomain, dir)
        if dir == '.' # current dir
          BooticCli::FSTheme.new(File.expand_path(dir))
        else # use subdomain?
          BooticCli::FSTheme.new(File.expand_path(subdomain))
        end
      end

      def select_remote_theme(shop)
        BooticCli::APITheme.new(shop.theme)
      end

      # def current_theme(dir, subdomain)
      #   @dirname   = dirname_for(dir)

      #   @found_shop = if subdomain
      #     get_shop(subdomain) or raise "Couldn't find shop with subdomain #{subdomain}"
      #   else
      #     theme_shop = read_theme_yaml(dir)[:shop]

      #     # unless subdomain is given, deduce the current shop from the theme.yml file
      #     # if none found, then use the dirname, and if still none, then fall back to shops.first
      #     get_shop(theme_shop || @dirname) || root.shops.first
      #   end

      #   check_subdomain!(@found_shop.subdomain, @dirname)
      #   @found_shop.theme
      # end

      # def current_shop
      #   @found_shop
      # end

      # def get_shop(subdomain = nil)
      #   shop = if subdomain
      #     if root.has?(:all_shops)
      #       root.all_shops(subdomains: subdomain).items.first
      #     else
      #       root.shops.select { |s| s.subdomain == subdomain }.first
      #     end
      #   else
      #     root.shops.first
      #   end
      # end

      # def check_subdomain!(subdomain, dirname)
      #   if dirname != subdomain
      #     input = ask("Shop #{highlight(subdomain)} doesn't match the current directory name: #{highlight(dirname)}. Is that OK? [y]")
      #     unless ['', 'y'].include?(input.downcase)
      #       abort 'Thought so.'
      #     end
      #   end
      # end

      # def dirname_for(dir)
      #   File.basename(File.expand_path(dir))
      # end

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

      # def theme_exists?(dir)
      #   File.exist?(File.join(dir, 'layout.html'))
      # end

      # def read_theme_yaml(dir)
      #   YAML.load_file(File.join(dir, 'theme.yml'))
      # rescue Errno::ENOENT => e
      #   {}
      # end

      # def write_theme_yaml(dir)
      #   path = File.join(dir, 'theme.yml')
      #   obj  = { title: @found_shop.subdomain, description: 'Theme for #{@found_shop.subdomain}' }
      #   File.open(path, 'w') { |f| f.write(YAML.dump(obj)) }
      # end

      def maybe_update(modified_templates, source_name, target_name, &block)
        modified_templates.each do |t|
          puts "---------"
          puts "#{source_name} #{t.file_name} was modified at #{t.updated_on} (more recent than #{target_name}):"
          puts "---------"
          puts t.diff.to_s(:color)

          input = ask("\nUpdate #{target_name} #{t.file_name}? [y]")
          next unless input == '' or input.strip.downcase == 'y'

          yield t
        end
      end

      def upsert(theme, path)
        item, type = FSTheme.resolve_file(path)
        case type
        when :template
          theme.add_template item.file_name, item.body
        when :asset
          theme.add_asset item.file_name, item.file
        end
        puts "Uploaded #{type}: #{item.file_name}"
      end

      def delete(theme, path)
        type = FSTheme.resolve_type(path)
        file_name = File.basename(path)
        case type
        when :template
          theme.remove_template file_name
        when :asset
          theme.remove_asset file_name
        end
        puts "Deleted remote #{type}: #{file_name}"
      end

      # def delete_file(path)
      #   File.unlink path
      #   puts "Deleted local file: #{path}"
      # end

      # def delete_template(theme, path)
      #   fname = File.basename(path)
      #   tpl = theme.templates.find{|t| t.file_name == fname}
      #   return unless tpl

      #   if tpl.has?(:delete_template)
      #     puts "Deleting remote template: #{path}"
      #     tpl.delete_template
      #   else
      #     puts 'Template cannot be deleted. Re-fetching...'
      #     write_local(path, tpl.body)
      #   end
      # end

      # def delete_asset(theme, path)
      #   fname = File.basename(path)
      #   asset = theme.assets.find { |t| t.file_name == fname }
      #   return unless asset
      #   puts "Deleting remote asset: #{path}"
      #   asset.delete_theme_asset
      # end

      # def upsert_template(theme, path)
      #   confirm_upload(theme.create_template(
      #     file_name: File.basename(path),
      #     body: File.read(path)
      #   ), path)
      # end

      # def upsert_asset(theme, path)
      #   puts "Upserting asset: #{path}"
      #   confirm_upload(theme.create_theme_asset(
      #     file_name: File.basename(path),
      #     data: File.new(path)
      #   ), path)
      # end

      # def confirm_upload(entity, path)
      #   if entity.has?(:errors)
      #     puts "File has errors: #{File.basename(path)}"
      #     entity.errors.each do |e|
      #       puts [" --> ", e.field, e.messages.join(', ')].join(' ')
      #     end
      #   else
      #     puts "Uploaded file: #{File.basename(path)}"
      #   end
      # end

      def copy_templates(from, to, opts = {})
        from.templates.each do |t|
          to.add_template t.file_name, t.body
        end
      end

      def copy_assets(from, to, opts = {})
        queue = Queue.new

        threads = from.assets.map do |a|
          target_asset = to.assets.find{ |t| t.file_name == a.file_name }
          if target_asset && !opts[:overwrite]
            next unless opts[:interactive]
            input = ask("Asset exists: #{a.file_name}. Overwrite? [n]")
            next if input == '' or input.strip.downcase == 'n'
          end

          Thread.new do
            to.add_asset a.file_name, a.file
            queue << a.file_name
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

      # def has_dos_line_endings?(path)
      #   !!IO.read(path)["\r\n"]
      # end

      # def write_local(path, content, mode = 'w')
      #   if mode == 'w'
      #     # remove DOS line endings for new templates
      #     # or for existing ones that don't have any.
      #     if !File.exist?(path) or !has_dos_line_endings?(path)
      #       content = StringUtils.normalize_endings(content)
      #     end
      #   end

      #   File.open(path, mode) do |io|
      #     io.write(content)
      #   end

      #   puts "Wrote #{File.basename(path)}"
      #   path
      # end

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
