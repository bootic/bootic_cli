module BooticCli
  class APITheme
    def initialize(theme)
      @theme = theme
    end

    def templates
      theme.templates
    end

    def assets
      theme.assets
    end

    def add_template(file_name, body)
      check_errors! theme.create_template(
        file_name: file_name,
        body: body
      )
    end

    def remove_template(file_name)
      tpl = theme.templates.find { |t| t.file_name == file_name }
      check_errors!(tpl.delete_template) if tpl && tpl.can?(:delete_template)
    end

    def add_asset(file_name, file)
      check_errors! theme.create_theme_asset(
        file_name: file_name,
        data: file
      )
    end

    def remove_asset(file_name)
      asset = theme.assets.find{|t| t.file_name == file_name }
      check_errors!(asset.delete_theme_asset) if asset
    end

    private
    attr_reader :theme

    class EntityErrors < StandardError
      attr_reader :errors
      def initialize(errors)
        @errors = errors
        super "Entity has errors: #{errors.map(&:field)}"
      end
    end

    def check_errors!(entity)
      if entity.has?(:errors)
        raise EntityErrors.new(entity.errors)
      end

      entity
    end
  end
end
