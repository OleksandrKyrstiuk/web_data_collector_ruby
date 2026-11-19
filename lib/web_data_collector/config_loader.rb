require 'yaml'

module WebDataCollector
  class ConfigError < StandardError; end

  class ConfigLoader
    REQUIRED_SETTINGS = %w[application source database output].freeze

    attr_reader :settings, :selectors

    def initialize(settings_path: 'config/settings.yml', selectors_path: 'config/selectors.yml')
      @settings = load_yaml(settings_path)
      @selectors = load_yaml(selectors_path)
      validate!
    end

    private

    def load_yaml(path)
      raise ConfigError, "Конфігураційний файл не знайдено: #{path}" unless File.exist?(path)

      YAML.safe_load_file(path, aliases: true) || {}
    rescue Psych::SyntaxError => e
      raise ConfigError, "Помилка синтаксису YAML у файлі #{path}: #{e.message}"
    end

    def validate!
      missing = REQUIRED_SETTINGS.reject { |key| @settings.key?(key) }
      raise ConfigError, "У settings.yml відсутні обов'язкові секції: #{missing.join(', ')}" unless missing.empty?

      if @selectors.empty?
        raise ConfigError, 'Файл selectors.yml порожній або не містить правил парсингу'
      end
    end
  end
end