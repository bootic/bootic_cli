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

      def pull(local_theme, remote_theme, delete: true)
        diff = ThemeDiff.new(source: local_theme, target: remote_theme, force_update: true)
        check_dupes!(local_theme.assets)

        download_opts = {
          overwrite: false,
          interactive: true
        }

        notice 'Updating local templates...'
        maybe_update(diff.updated_in_target.templates, 'remote', 'local') do |t|
          local_theme.add_template t.file_name, t.body
        end

        if delete
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

      def push(local_theme, remote_theme, delete: true)
        diff = ThemeDiff.new(source: local_theme, target: remote_theme, force_update: true)
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

        if delete
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
          local_theme.add_template(t.file_name, t.body)
        end

        notice 'Updating remote templates...'
        maybe_update(diff.updated_in_source.templates, 'local', 'remote') do |t|
          remote_theme.add_template(t.file_name, t.body)
        end

        # now, download missing files on local end
        notice 'Downloading missing local templates & assets...'
        copy_templates(diff.missing_in_source, local_theme, download_opts)
        copy_assets(diff.missing_in_source, local_theme, download_opts)

        # now, upload missing files on remote
        notice 'Uploading missing remote templates & assets...'
        copy_templates(diff.missing_in_target, remote_theme, download_opts)
        copy_assets(diff.missing_in_target, remote_theme, download_opts)
      end

      def compare(local_theme, remote_theme)
        diff = ThemeDiff.new(source: local_theme, target: remote_theme)
        notice 'Comparing local and remote copies of theme...'

        unless diff.any?
          prompt.say "No changes between versions."
          return
        end

        notice "Local <--- Remote"

        diff.updated_in_target.templates.each do |t|
          puts "Updated template in remote: #{t.file_name} (updated at #{t.updated_on})"
          puts t.diff.to_s(:color)
        end

        diff.updated_in_target.assets.each do |t|
          puts "Updated asset in remote: #{t.file_name} (updated at #{t.updated_on})"
        end

        diff.missing_in_source.templates.each do |t|
          puts "Remote template not in local dir: #{t.file_name}"
        end

        diff.missing_in_source.assets.each do |t|
          puts "Remote asset not in local dir: #{t.file_name}"
        end

        notice "Local ---> Remote"

        diff.updated_in_source.templates.each do |t|
          puts "Updated locally: #{t.file_name} (updated at #{t.updated_on})"
          puts t.diff.to_s(:color)
        end

        diff.updated_in_source.assets.each do |t|
          puts "Updated locally: #{t.file_name} (updated at #{t.updated_on})"
        end

        diff.missing_in_target.templates.each do |f|
          puts "Local template not in remote: #{f.file_name}"
        end

        diff.missing_in_target.assets.each do |f|
          puts "Local asset not in remote: #{f.file_name}"
        end
      end

      def publish(local_theme, remote_theme)
        raise "This command is meant for dev themes only" unless remote_theme.dev?

        changes = ThemeDiff.new(source: local_theme, target: remote_theme)
        if changes.any?
          prompt.say "There are differences between your local and the remote version of your shop's development theme."
          if prompt.yes_or_no? "Push your local changes now?", true
            push(local_theme, remote_theme, delete: true)
          else
            prompt.say "No problem. Please make sure both versions are synced before publishing.", :magenta
            exit(1)
          end
        end

        delete_dev = prompt.yes_or_no? "Delete the development copy of your theme after publishing?", true
        prompt.notice "Alrighty! Publishing your development theme..."
        updated_theme = remote_theme.publish(delete: delete_dev)

        prompt.notice "Yay! Your development theme has been made public. Take a look at #{remote_theme.path.sub('/preview/dev', '')}"

        if delete_dev
          prompt.say "Run `bootic themes dev` on this directory to create a development copy of your public theme later."
        end
      end

      def watch(dir, remote_theme, watcher: Listen)
        listener = watcher.to(dir) do |modified, added, removed|

          if modified.any?
            modified.each do |path|
              upsert_file(remote_theme, path, dir)
            end
          end

          if added.any?
            added.each do |path|
              upsert_file(remote_theme, path, dir)
            end
          end

          if removed.any?
            removed.each do |path|
              delete_file(remote_theme, path, dir)
            end
          end

          # update local cache
          remote_theme.reload!
        end

        notice "Watching #{File.expand_path(dir)} for changes..."
        listener.start

        # ctrl-c
        Signal.trap('INT') {
          begin
            listener.stop
          rescue ThreadError => e # cant be called from trap context
            # nil
          end
          puts "\nSee you in another lifetime, brother."
          exit
        }

        prompt.say "Preview changes at #{remote_theme.path}. Hit Ctrl-C to stop watching for changes.", :cyan
        Kernel.sleep
      end

      private
      attr_reader :prompt

      def check_dupes!(list)
        names = list.map { |f| f.file_name.downcase }
        dupes = names.group_by { |e| e }.select { |k, v| v.size > 1 }.map(&:first)

        dupes.each do |downcased|
          arr = list.select { |f| f.file_name.downcase == downcased }
          prompt.say(" --> Name clash between files: " + arr.map(&:file_name).join(', '), :red)
        end

        if dupes.any?
          prompt.say("Please ensure there are no name clashes before continuing. Thanks!")
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
        from.templates.each do |f|
          puts "Removing template #{highlight(f.file_name)}"
          to.remove_template(f.file_name)
        end
        from.assets.each do |f|
          puts "Removing asset #{highlight(f.file_name)}"
          to.remove_asset(f.file_name)
        end
      end

      def copy_templates(from, to, opts = {})
        from.templates.each do |t|
          handle_file_errors(:template, t) do
            to.add_template(t.file_name, t.body)
            puts "Copied template #{highlight(t.file_name)}"
          end
        end
      end

      def copy_assets(from, to, opts = {})
        files = from.assets.find_all do |a|
          if opts[:overwrite]
            true
          elsif existing = to.assets.find { |t| t.file_name == a.file_name }
            if existing == a # exact copy, no need to overwrite
              false
            else
              opts[:interactive] && prompt.yes_or_no?("Asset exists: #{highlight(a.file_name)}. Overwrite?", false)
            end
          else
            true
          end
        end

        pool = BooticCli::WorkerPool.new(CONCURRENCY)

        # puts "Downloading assets: #{files.count}"
        files.each do |a|
          pool.schedule do
            handle_file_errors(:asset, a) do
              to.add_asset(a.file_name, a.file)
              size_str = a.file_size.to_i > 0 ? " (#{a.file_size} bytes)" : ''
              puts "Copied asset #{highlight(a.file_name)}#{size_str}"
            end
          end
        end

        pool.start
      end

      def upsert_file(theme, path, dir)
        return if File.basename(path)[0] == '.' # filter out .lock and .state

        item, type = FSTheme.resolve_file(path, dir)
        success = handle_file_errors(type, item) do
          case type
          when :template
            theme.add_template(item.file_name, item.body)
          when :asset
            theme.add_asset(item.file_name, item.file)
          end
        end
        puts "Uploaded #{type}: #{highlight(item.file_name)}" if success
      end

      def delete_file(theme, path, dir)
        type = FSTheme.resolve_type(path)
        success = case type
        when :template
          file_name = FSTheme.resolve_path(path, dir)
          theme.remove_template(file_name)
        when :asset
          file_name = File.basename(path)
          theme.remove_asset(file_name)
        else
          raise "Invalid type: #{type}"
        end
        puts "Deleted remote #{type}: #{highlight(file_name)}" if success
      end

      def handle_file_errors(type, file, &block)
        begin
          yield
          true
        rescue APITheme::EntityErrors => e
          fields = e.errors.map(&:field)

          if fields.include?('$.updated_on') || fields.include?('updated_on')
            prompt.say("#{file.file_name} timestamp #{e.errors.first.messages.first}", :red)
            abort
          end

          error_msg = if fields.include?('file_content_type') or fields.include?('content_type')
            "is an unsupported file type for #{type}s."
          elsif fields.include?('file_file_size') # big asset
            size_str = file.file_size.to_i > 0 ? "(#{file.file_size} KB) " : ''
            "#{size_str}is heavier than the maximum allowed for assets (1 MB)"
          elsif fields.include?('body') # big template
            str = file.file_name[/\.(html|liquid)$/] ? "Try splitting it into smaller chunks" : "Try saving it as an asset instead"
            str += ", since templates can hold up to 64 KB of data."
          else
            "has invalid #{fields.join(', ')}"
          end

          prompt.say("#{file.file_name} #{error_msg}. Skipping...", :red)
          false # just continue, don't abort

        rescue JSON::GeneratorError => e
          prompt.say("#{file.file_name} looks like a binary file, not a template. Skipping...", :red)
          false # just continue, don't abort

        rescue APITheme::InvalidRequest => e
          prompt.say("Invalid request: #{e.message}. Skipping...", :red)
          false # just continue, don't abort

        rescue APITheme::UnknownResponse => e # 502s, 503s, etc
          prompt.say("Got an unknown response from server: #{e.message}. Please try again in a minute.", :red)
          abort

        rescue Net::OpenTimeout, Net::ReadTimeout => e
          prompt.say("I'm having trouble connecting to the server. Please try again in a minute.", :red)
          abort

        rescue BooticClient::ServerError => e
          prompt.say("Couldn't save #{file.file_name}. Please try again in a few minutes.", :red)
          abort
        end
      end
    end
  end
end

