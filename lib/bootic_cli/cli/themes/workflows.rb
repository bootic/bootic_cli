require 'bootic_cli/cli/themes/updated_theme'
require 'bootic_cli/cli/themes/missing_items_theme'
require 'bootic_cli/cli/themes/theme_diff'

module BooticCli
  class NullPrompt
    def self.yes_or_no?(str, default)
      true
    end

    def self.notice(str)

    end

    def self.puts(*_)

    end
  end

  class Workflows
    def initialize(prompt: NullPrompt)
      @prompt = prompt
    end

    def pull(local_theme, remote_theme, destroy: true)
      # tpls and assets present locally that have been updated remotely
      updated_in_remote = BooticCli::UpdatedTheme.new(source: remote_theme, target: local_theme)
      # tpls and assets that were removed remotely
      removed_in_remote = BooticCli::MissingItemsTheme.new(source: local_theme, target: remote_theme)
      # tpls and assets present in remote that are not in local
      new_files_in_remote = BooticCli::MissingItemsTheme.new(source: remote_theme, target: local_theme)

      # diff = ThemeDiff.new(source: local_theme, target: remote_theme, force_update: true)
      check_dupes!(local_theme.assets)

      download_opts = {
        overwrite: false,
        interactive: true
      }

      notice 'Updating local templates...'
      maybe_update(updated_in_remote.templates, 'remote', 'local') do |t|
        local_theme.add_template t.file_name, t.body
      end

      if destroy
        notice 'Removing local files that were removed on remote...'
        remove_all(removed_in_remote, local_theme)
      else
        notice 'Not removing local files that were removed on remote.'
      end

      notice 'Pulling missing files from remote...'
      copy_templates(new_files_in_remote, local_theme, download_opts)
      # lets copy all of them and let user decide to overwrite existing
      copy_assets(remote_theme, local_theme, download_opts)
    end

    def push(local_theme, remote_theme, destroy: true)
      updated_in_local = BooticCli::UpdatedTheme.new(source: local_theme, target: remote_theme)
      removed_in_local = BooticCli::MissingItemsTheme.new(source: remote_theme, target: local_theme)
      new_files_in_local = BooticCli::MissingItemsTheme.new(source: local_theme, target: remote_theme)

      check_dupes!(local_theme.assets)

      notice 'Pushing local changes to remote...'

      # update existing templates
      notice 'Updating remote templates...'
      maybe_update(updated_in_local.templates, 'local', 'remote') do |t|
        remote_theme.add_template t.file_name, t.body
      end

      notice 'Pushing files that are missing in remote...'
      copy_assets(new_files_in_local, remote_theme, overwrite: true)
      copy_templates(new_files_in_local, remote_theme)

      if destroy
        notice 'Removing remote files that were removed locally...'
        remove_all(removed_in_local, remote_theme)
      else
        notice 'Not removing remote files that were removed locally.'
      end
    end

    def sync(local_theme, remote_theme)
      updated_in_local = BooticCli::UpdatedTheme.new(source: local_theme, target: remote_theme)
      updated_in_remote = BooticCli::UpdatedTheme.new(source: remote_theme, target: local_theme)
      new_files_in_local = BooticCli::MissingItemsTheme.new(source: local_theme, target: remote_theme)
      new_files_in_remote = BooticCli::MissingItemsTheme.new(source: remote_theme, target: local_theme)

      check_dupes!(local_theme.assets)
      notice 'Syncing local copy with remote...'

      download_opts = {
        overwrite: false,
        interactive: false
      }

      # first, update existing templates in each side
      notice 'Updating local templates...'
      maybe_update(updated_in_remote.templates, 'remote', 'local') do |t|
        local_theme.add_template t.file_name, t.body
      end

      notice 'Updating remote templates...'
      maybe_update(updated_in_local.templates, 'local', 'remote') do |t|
        remote_theme.add_template t.file_name, t.body
      end

      # now, download missing files on local end
      notice 'Downloading missing local templates & assets...'
      copy_templates(new_files_in_remote, local_theme, download_opts)
      copy_assets(new_files_in_remote, local_theme, overwrite: true)

      # now, upload missing files on remote
      notice 'Uploading missing remote templates & assets...'
      copy_templates(new_files_in_local, remote_theme, download_opts)
      copy_assets(new_files_in_local, remote_theme, overwrite: true)
    end

    def compare(local_theme, remote_theme)
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

    private
    attr_reader :prompt

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

    def maybe_update(modified_templates, source_name, target_name, &block)
      modified_templates.each do |t|
        puts "---------"
        puts "#{source_name} #{t.file_name} was modified at #{t.updated_on} (more recent than #{target_name}):"
        puts "---------"
        puts t.diff.to_s(:color)

        yield(t) if prompt.yes_or_no?("Update #{target_name} #{t.file_name}?", true)
        # input = ask("\nUpdate #{target_name} #{t.file_name}? [y]")
        # next unless input == '' or input.strip.downcase == 'y'
      end
    end

    def notice(str)
      prompt.notice str
    end

    def puts(*args)
      prompt.puts *args
    end

    def remove_all(from, to)
      from.templates.each { |f| to.remove_template(f.file_name) }
      from.assets.each { |f| to.remove_asset(f.file_name) }
    end

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
          next unless prompt.yes_or_no?("Asset exists: #{a.file_name}. Overwrite?", false)
          # input = ask("Asset exists: #{a.file_name}. Overwrite? [n]")
          # next if input == '' or input.strip.downcase == 'n'
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
  end
end

