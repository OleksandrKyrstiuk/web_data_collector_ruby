module WebDataCollector
  class PipelineValidationError < StandardError; end

  class PipelineRunner
    SUPPORTED_STORAGES = %i[sqlite].freeze
    SUPPORTED_EXPORTS = %i[json csv].freeze

    def self.run_file(dsl_path, parser: nil)
      pipeline = PipelineBuilder.load_file(dsl_path)
      new(pipeline, parser: parser).run
    end

    def initialize(pipeline, parser: nil, logger: nil)
      @pipeline = pipeline
      @custom_parser = parser
      @logger = logger || AppLogger.build(log_dir: 'logs', level: 'info')
    end

    # Головний цикл виконання DSL-сценарію
    def run
      validate!
      @logger.info("=== Запуск DSL-конвеєра: '#{@pipeline.name}' ===")
      @logger.info("Джерело: #{@pipeline.source_url}")

      collection = fetch_collection
      @logger.info("Отримано записів до фільтрації: #{collection.size}")

      filtered = apply_filters(collection)
      @logger.info("Залишилось записів після DSL-фільтрів: #{filtered.size}")

      saved_count = persist_data(filtered)
      export_data(filtered)

      @logger.info("=== DSL-конвеєр '#{@pipeline.name}' успішно виконано ===")
      { pipeline: @pipeline.name, fetched: collection.size, filtered: filtered.size, saved: saved_count }
    end

    private

    # Перевірка коректності правил і параметрів DSL-конвеєра до запуску парсера
    def validate!
      raise PipelineValidationError, 'Конфігурацію конвеєра не передано' unless @pipeline.is_a?(Pipeline)
      raise PipelineValidationError, 'Не вказано адресу джерела (source)' if @pipeline.source_url.to_s.strip.empty?
      raise PipelineValidationError, 'Не визначено жодного поля у блоці extract' if @pipeline.fields.empty?

      @pipeline.fields.each do |field_name, rule|
        if rule['selector'].to_s.strip.empty?
          raise PipelineValidationError, "Некоректний або порожній CSS-селектор для поля '#{field_name}'"
        end
      end

      if @pipeline.storage
        adapter = @pipeline.storage[:adapter]
        unless SUPPORTED_STORAGES.include?(adapter)
          raise PipelineValidationError, "Непідтримуваний тип сховища: #{adapter}"
        end
      end

      @pipeline.exports.each do |exp|
        unless SUPPORTED_EXPORTS.include?(exp[:format])
          raise PipelineValidationError, "Непідтримуваний формат експорту: #{exp[:format]}"
        end
        raise PipelineValidationError, 'Не вказано шлях для експорту файлу' if exp[:path].to_s.strip.empty?
      end
    end

    # Збір даних через зовнішній парсер (ін'єкція для тестів) або стандартний SimpleWebsiteParser
    def fetch_collection
      if @custom_parser
        @custom_parser.parse
      else
        selectors_cfg = {
          'item_card' => @pipeline.card_selector,
          'fields' => @pipeline.fields
        }
        SimpleWebsiteParser.new(
          url: @pipeline.source_url,
          selectors_config: selectors_cfg,
          logger: @logger
        ).parse
      end
    end

    # Послідовна фільтрація колекції 
    def apply_filters(collection)
      @pipeline.filters.reduce(collection) do |current_collection, rule|
        current_collection.filter_by do |item|
          if rule[:field]
            value = item.public_send(rule[:field])
            rule[:block].call(value)
          else
            rule[:block].call(item)
          end
        end
      end
    end

    # Збереження результатів у SQLite та мультиекспорт у всі вказані формати
    def persist_data(collection)
      return 0 unless @pipeline.storage

      db = DatabaseConnector.new(
        db_path: @pipeline.storage[:db_path],
        table_name: @pipeline.storage[:table],
        logger: @logger
      )
      db.save_collection(collection)
    ensure
      db&.close
    end

    def export_data(collection)
      @pipeline.exports.each do |exp|
        case exp[:format]
        when :json
          Exporters::JsonExporter.export(collection, exp[:path])
        when :csv
          Exporters::CsvExporter.export(collection, exp[:path])
        end
        @logger.info("DSL експорт (#{exp[:format].upcase}) виконано: #{exp[:path]}")
      end
    end
  end
end