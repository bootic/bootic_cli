require 'fileutils'
require 'open-uri'
require 'thread'
require 'listen'
require 'diffy'

module BooticCli
  module StringUtils
    def self.normalize_endings(str)
      str.to_s.gsub(/\r\n?/, "\n")
    end
  end

  module Commands
    class Themes < BooticCli::Command
      class ThemeDiff
        ASSETS_DIR_EXP = /assets/

        def initialize(dir, theme, force_update = false)
          @local_files, @theme = Dir.glob(File.join(dir, '**/*')), theme
          @force_update = force_update

          # ensure local templates and assets are read/cached before any changes are made
          reload
        end

        def reload
          @cache = {}
          local_templates
          local_assets
          theme_templates
          theme_assets
          templates_updated_in_remote
          templates_updated_locally
        end

        def templates_updated_in_remote
          @cache[:updated_remote_templates] ||= find_modified_files(local_templates, theme_templates)
        end

        def templates_updated_locally
          @cache[:updated_local_templates] ||= find_modified_files(theme_templates, local_templates)
        end

        # templates in theme that are not in dir
        def remote_templates_not_in_dir
          @cache[:new_remote_templates] ||= find_missing_files(theme_templates, local_templates)
        end

        # assets in theme that are not in dir
        def remote_assets_not_in_dir
          @cache[:new_remote_assets] ||= find_missing_files(theme_assets, local_assets)
        end

        # templates in dir that are not in theme
        def local_templates_not_in_remote
          @cache[:new_local_templates] ||= find_missing_files(local_templates, theme_templates)
        end

        # assets in dir that are not in theme
        def local_assets_not_in_remote
          @cache[:new_local_assets] ||= find_missing_files(local_assets, theme_assets)
        end

        def local_templates
          @cache[:local_templates] ||= filtered_files { |path| !(path =~ ASSETS_DIR_EXP) }
        end

        def local_assets
          @cache[:local_assets] ||= filtered_files { |path| path =~ ASSETS_DIR_EXP && !File.directory?(path) }
        end

        private
        attr_reader :local_files, :theme, :force_update

        class LocalFile
          attr_reader :file_name, :path
          attr_accessor :diff

          def initialize(path)
            @path = path
            @file_name = File.basename(path)
            @io = File.new(path)
          end

          def body
            @body ||= @io.read
          end

          def updated_on
            @io.mtime.utc.iso8601
          end
        end

        ModifiedFile = Struct.new('ModifiedFile', :file_name, :updated_on, :new_body, :diff)

        def find_missing_files(set1, set2)
          file_names = set2.map(&:file_name)
          set1.select do |f|
            !file_names.include?(f.file_name)
          end
        end

        # returns list of items from set1 that have a more recent timestamp in set2
        def find_modified_files(set1, set2)
          by_filename = {}
          set2.each { |f|
            by_filename[f.file_name] = { updated_on: f.updated_on, body: f.body }
          }

          set1.map do |f|
            other_file = by_filename[f.file_name]
            if other_file.nil?
              # puts "File not found in set1: #{f.file_name}"
              next
            end

            # normalize endings when comparing files so we don't have any noise in them
            diff = Diffy::Diff.new(StringUtils.normalize_endings(f.body), StringUtils.normalize_endings(other_file[:body]), context: 1)
            next if diff.to_s.empty?

            original_time = Time.parse f.updated_on
            updated_time  = Time.parse other_file[:updated_on]

            # puts " -- #{f.file_name}\n#{original_time}\n#{updated_time}"
            if !force_update && updated_time <= original_time
              next
            end

            ModifiedFile.new(f.file_name, other_file[:updated_on], other_file[:body], diff)
          end.compact
        end

        def theme_templates
          @cache[:theme_templates] ||= theme.templates
        end

        def theme_assets
          @cache[:theme_assets] ||= theme.assets
        end

        def filtered_files(&block)
          local_files.select(&block).map do |path|
            LocalFile.new(path)
          end
        end
      end

      desc 'pull [shop] [dir]', 'Pull latest theme changes in [shop] into directory [dir] (current by default)'
      option :destroy, banner: '<true|false>', default: 'true'
      def pull(subdomain = nil, dir = '.')
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

      desc 'push [shop] [dir]', 'Push all local theme files in [dir] to remote shop [shop]'
      option :destroy, banner: '<true|false>', default: 'true'
      def push(subdomain = nil, dir = '.')
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

      desc 'sync [shop] [dir]', 'Sync local theme copy in [dir] with remote [shop]'
      def sync(subdomain = nil, dir = '.')
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

      desc 'compare [shop] [dir]', 'Show differences between local and remote copies'
      def compare(subdomain = nil, dir = '.')

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

      desc 'watch [shop] [dir]', 'Watch theme directory at [dir] and create/update/delete the one in [shop] when changed'
      def watch(subdomain = nil, dir = '.')
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
      rescue => e
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
