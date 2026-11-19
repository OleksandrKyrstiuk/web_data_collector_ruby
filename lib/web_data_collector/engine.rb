module WebDataCollector
  class Engine

    def initialize(settings_path: 'config/settings.yml', selectors_path: 'config/selectors.yml')
      @config = ConfigLoader.new(settings_path: settings_path, selectors_path: selectors_path)
      @settings = @config.settings
      @logger = AppLogger.build(
        log_dir: 'logs',
        level: @settings.dig('application', 'log_level') || 'info'
      )
    end

    # Головний метод оркестрації: виконує повний цикл збору, валідації, збереження та експорту даних
    def run
      @logger.info('=== Запуск конвеєра WebDataCollector ===')
      source_url = @settings.dig('source', 'url')
      mode = @settings.dig('application', 'mode') || 'fake'
      @logger.info("Джерело даних: #{source_url} (режим: #{mode})")

      raw_collection = collect_data(mode, source_url)
      @logger.info("Отримано сирих записів: #{raw_collection.size}")

      valid_collection = raw_collection.filter_by do |item|
        !item.title.to_s.strip.empty? && !item.url.to_s.strip.empty?
      end
      @logger.info("Після валідації залишилось записів: #{valid_collection.size}")

      db = DatabaseConnector.new(
        db_path: @settings.dig('database', 'path'),
        table_name: @settings.dig('database', 'table'),
        logger: @logger
      )
      saved_count = db.save_collection(valid_collection)
      total_in_db = db.total_count
      @logger.info("Нових записів збережено в SQLite: #{saved_count} (усього в базі: #{total_in_db})")

      out_dir = @settings.dig('output', 'directory') || 'output'
      json_path = File.join(out_dir, @settings.dig('output', 'json_file') || 'vacancies.json')
      csv_path = File.join(out_dir, @settings.dig('output', 'csv_file') || 'vacancies.csv')

      Exporters::JsonExporter.export(valid_collection, json_path)
      Exporters::CsvExporter.export(valid_collection, csv_path)
      @logger.info("Експортовано результати у #{json_path} та #{csv_path}")

      @logger.info('=== Виконання успішно завершено ===')
      { fetched: raw_collection.size, saved: saved_count, total_db: total_in_db }
    rescue ConfigError, DatabaseError, SimpleWebsiteParser::ParserError, StandardError => e
      @logger&.error("Критична помилка виконання: #{e.class} - #{e.message}")
      raise
    ensure
      db&.close
    end

    private

    # Стратегія вибору джерела даних залежно від налаштування application.mode
    def collect_data(mode, source_url)
      case mode
      when 'fake'
        FakeDataGenerator.generate(8)
      when 'live'
        site_key = @settings.dig('source', 'site_key') || 'djinni'
        parser = SimpleWebsiteParser.new(
          url: source_url,
          selectors_config: @config.selectors[site_key],
          timeout: @settings.dig('source', 'timeout') || 15,
          headless: @settings.fetch('source', {}).fetch('headless', true),
          logger: @logger
        )
        parser.parse
      else
        raise ConfigError, "Невідомий режим роботи в settings.yml: #{mode}"
      end
    end
  end
end