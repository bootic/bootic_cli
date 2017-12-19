require 'listen'
require 'thread'
require 'bootic_cli/themes/theme_diff'
require 'bootic_cli/themes/fs_theme'
require 'bootic_cli/worker_pool'

module BooticCli
  module Themes
    class NullPrompt
      def self.yes_or_no?(str, default)
        true
      end

      def self.notice(str)

      end

      def self.highlight(str)

      end

      def self.say(*_)

      end
    end

    class Workflows
      CONCURRENCY = 10

      def initialize(prompt: NullPrompt)
        @prompt = prompt
      end

      def pull(local_theme, remote_theme, destroy: true)
        diff = ThemeDiff.new(source: local_theme, target: remote_theme)
        check_dupes!(local_theme.assets)

        download_opts = {
          overwrite: false,
          interactive: true
        }

        notice 'Updating local templates...'
        maybe_update(diff.updated_in_target.templates, 'remote', 'local') do |t|
          local_theme.add_template t.file_name, t.body
        end

        if destroy
          notice 'Removing local files that were removed on remote...'
          remove_all(diff.missing_in_target, local_theme)
        else
          notice 'Not removing local files that were removed on remote.'
        end

        notice 'Pulling missing files from remote...'
        copy_templates(diff.missing_in_source, local_theme, download_opts)
        # lets copy all of them and let user decide to overwrite existing
        copy_assets(remote_theme, local_theme, download_opts)
      end

      def push(local_theme, remote_theme, destroy: true)
        diff = ThemeDiff.new(source: local_theme, target: remote_theme)
        check_dupes!(local_theme.assets)

        notice 'Pushing local changes to remote...'

        # update existing templates
        notice 'Updating remote templates...'
        maybe_update(diff.updated_in_source.templates, 'local', 'remote') do |t|
          remote_theme.add_template t.file_name, t.body
        end

        notice 'Pushing files that are missing in remote...'
        copy_assets(diff.missing_in_target, remote_theme, overwrite: true)
        copy_templates(diff.missing_in_target, remote_theme)

        if destroy
          notice 'Removing remote files that were removed locally...'
          remove_all(diff.missing_in_source, remote_theme)
        else
          notice 'Not removing remote files that were removed locally.'
        end
      end

      def sync(local_theme, remote_theme)
        diff = ThemeDiff.new(source: local_theme, target: remote_theme)
        check_dupes!(local_theme.assets)
        notice 'Syncing local copy with remote...'

        download_opts = {
          overwrite: false,
          interactive: false
        }

        # first, update existing templates in each side
        notice 'Updating local templates...'
        maybe_update(diff.updated_in_target.templates, 'remote', 'local') do |t|
          local_theme.add_template t.file_name, t.body
        end

        notice 'Updating remote templates...'
        maybe_update(diff.updated_in_source.templates, 'local', 'remote') do |t|
          remote_theme.add_template t.file_name, t.body
        end

        # now, download missing files on local end
        notice 'Downloading missing local templates & assets...'
        copy_templates(diff.missing_in_source, local_theme, download_opts)
        copy_assets(diff.missing_in_source, local_theme, overwrite: true)

        # now, upload missing files on remote
        notice 'Uploading missing remote templates & assets...'
        copy_templates(diff.missing_in_target, remote_theme, download_opts)
        copy_assets(diff.missing_in_target, remote_theme, overwrite: true)
      end

      def compare(local_theme, remote_theme)
        diff = ThemeDiff.new(source: local_theme, target: remote_theme)
        notice 'Comparing local and remote copies of theme...'

        notice "Local <--- Remote"

        diff.updated_in_target.templates.each do |t|
          puts "Updated in remote: #{t.file_name}"
        end

        diff.missing_in_source.templates.each do |t|
          puts "Remote template not in local dir: #{t.file_name}"
        end

        diff.missing_in_source.assets.each do |t|
          puts "Remote asset not in local dir: #{t.file_name}"
        end

        notice "Local ---> Remote"

        diff.updated_in_source.templates.each do |t|
          puts "Updated locally: #{t.file_name}"
        end

        diff.missing_in_target.templates.each do |f|
          puts "Local template not in remote: #{f.file_name}"
        end

        diff.missing_in_target.assets.each do |f|
          puts "Local asset not in remote: #{f.file_name}"
        end
      end

      def watch(dir, remote_theme, watcher: Listen)
        listener = watcher.to(dir) do |modified, added, removed|
          if modified.any?
            modified.each do |path|
              upsert_file remote_theme, path
            end
          end

          if added.any?
            added.each do |path|
              upsert_file remote_theme, path
            end
          end

          if removed.any?
            removed.each do |path|
              delete_file remote_theme, path
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

        Kernel.sleep
      end

      private
      attr_reader :prompt

      def check_dupes!(list)
        names = list.map { |f| f.file_name.downcase }
        dupes = names.group_by { |e| e }.select { |k, v| v.size > 1 }.map(&:first)

        dupes.each do |downcased|
          arr = list.select { |f| f.file_name.downcase == downcased }
          highlight(" --> Name clash between files: " + arr.map(&:file_name).join(', '), :red)
        end

        if dupes.any?
          highlight("Please ensure there are no name clashes before continuing. Thanks!")
          abort
        end
      end

      def maybe_update(modified_templates, source_name, target_name, &block)
        modified_templates.each do |t|
          puts "---------"
          puts "#{source_name} #{t.file_name} was modified at #{t.updated_on} (more recent than #{target_name}):"
          puts "---------"
          puts t.diff.to_s(:color)

          yield(t) if prompt.yes_or_no?("Update #{target_name} #{t.file_name}?", true)
        end
      end

      def notice(str)
        prompt.notice str
      end

      def puts(str)
        prompt.say str
      end

      def highlight(str)
        prompt.highlight str
      end

      def remove_all(from, to)
        from.templates.each { |f| to.remove_template(f.file_name) }
        from.assets.each { |f| to.remove_asset(f.file_name) }
      end

      def copy_templates(from, to, opts = {})
        from.templates.each do |t|
          to.add_template t.file_name, t.body
          puts "Copied #{t.file_name}"
        end
      end

      def copy_assets(from, to, opts = {})
        files = from.assets.find_all do |a|
          if opts[:overwrite]
            true
          else
            target_asset = to.assets.find{ |t| t.file_name == a.file_name }
            if target_asset
              opts[:interactive] && prompt.yes_or_no?("Asset exists: #{a.file_name}. Overwrite?", false)
            else
              true
            end
          end
        end

        pool = BooticCli::WorkerPool.new(CONCURRENCY)

        files.each do |a|
          pool.schedule do
            to.add_asset a.file_name, a.file
            puts "Copied asset #{a.file_name}"
          end
        end

        pool.start
      end

      def upsert_file(theme, path)
        item, type = FSTheme.resolve_file(path)
        case type
        when :template
          theme.add_template item.file_name, item.body
        when :asset
          theme.add_asset item.file_name, item.file
        end
        puts "Uploaded #{type}: #{item.file_name}"
      end

      def delete_file(theme, path)
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
    end
  end
end

