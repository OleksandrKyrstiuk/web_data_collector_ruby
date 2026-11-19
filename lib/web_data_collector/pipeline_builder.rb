# frozen_string_literal: true

module WebDataCollector
  class PipelineBuilder
    # Ізольований контекст для вкладеного блоку extract (дозволяє викликати field лише всередині extract)
    class ExtractContext
      def initialize(pipeline)
        @pipeline = pipeline
      end

      def field(name, selector:, attribute: 'text')
        @pipeline.fields[name.to_s] = {
          'selector' => selector,
          'attribute' => attribute.to_s
        }
      end
    end

    # Зчитує зовнішній файл сценарію та виконує його у контексті екземпляра PipelineBuilder
    def self.load_file(file_path)
      raise ArgumentError, "DSL-файл не знайдено: #{file_path}" unless File.exist?(file_path)

      builder = new
      builder.instance_eval(File.read(file_path, encoding: 'UTF-8'), file_path, 1)
      builder.pipeline
    end

    def initialize
      @pipeline = nil
    end

    # Коренева команда DSL (з аргументами створює конвеєр, без аргументів повертає зібраний об'єкт)
    def pipeline(name = nil, &block)
      return @pipeline if name.nil? && !block_given?

      @pipeline = Pipeline.new(name)
      instance_eval(&block) if block_given?
      @pipeline
    end

    def source(url)
      ensure_pipeline!
      @pipeline.source_url = url
    end

    # Перемикає контекст виконання на ExtractContext для збору CSS-селекторів полів
    def extract(card_selector: nil, &block)
      ensure_pipeline!
      @pipeline.card_selector = card_selector if card_selector
      ExtractContext.new(@pipeline).instance_eval(&block) if block_given?
    end

    def filter(field_name = nil, &block)
      ensure_pipeline!
      raise ArgumentError, 'Для конструкції filter потрібно передати блок умови' unless block_given?

      @pipeline.filters << { field: field_name&.to_sym, block: block }
    end

    def save_to(adapter, db_path: 'data/jobs.sqlite3', table: 'vacancies')
      ensure_pipeline!
      @pipeline.storage = { adapter: adapter.to_sym, db_path: db_path, table: table }
    end

    def export(format, path:)
      ensure_pipeline!
      @pipeline.exports << { format: format.to_sym, path: path }
    end

    private

    def ensure_pipeline!
      raise ArgumentError, 'Усі команди DSL мають бути всередині блоку pipeline "..." do ... end' unless @pipeline
    end
  end
end