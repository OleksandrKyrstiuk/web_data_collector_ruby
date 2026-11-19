require 'spec_helper'

RSpec.describe WebDataCollector do
  # 1. Тестування моделі даних: ініціалізація полів, автоматична мітка часу та серіалізація
  describe WebDataCollector::Item do
    it 'зберігає атрибути та коректно перетворюється у хеш' do
      item = described_class.new(
        title: 'Ruby Developer',
        company: 'Acme Corp',
        salary: '$3000',
        experience: '2 роки',
        url: 'https://djinni.co/jobs/1-ruby/'
      )

      expect(item.title).to eq('Ruby Developer')
      expect(item.to_h[:company]).to eq('Acme Corp')
      expect(item.to_h[:scraped_at]).not_to be_nil
    end
  end

  # 2. Тестування контейнера ItemCollection: контроль типів, сортування, фільтрація та метапрограмування
  describe WebDataCollector::ItemCollection do
    let(:item1) { WebDataCollector::Item.new(title: 'Junior Ruby', company: 'Beta', salary: '$1000', url: 'https://example.com/1') }
    let(:item2) { WebDataCollector::Item.new(title: 'Senior Ruby', company: 'Alpha', salary: '$4000', url: 'https://example.com/2') }

    it 'підтримує Enumerable, фільтрацію, сортування та перевірку типу' do
      collection = described_class.new([item1, item2])
      expect(collection.size).to eq(2)
      expect { collection.add('not_an_item') }.to raise_error(WebDataCollector::InvalidItemError)

      sorted = collection.sort_by_field(:company, direction: :asc)
      expect(sorted.first.company).to eq('Alpha')

      filtered = collection.filter_by { |i| i.title.include?('Senior') }
      expect(filtered.size).to eq(1)
    end

    it 'динамічно створює геттери та сеттери через define_dynamic_accessors' do
      collection = described_class.new([item1], dynamic_fields: [:source_site])
      collection.source_site = 'Djinni'
      expect(collection.source_site).to eq('Djinni')

      collection.define_dynamic_accessors(:custom_tag)
      collection.custom_tag = 'RubyJobs'
      expect(collection.respond_to?(:custom_tag)).to be(true)
      expect(collection.respond_to?(:custom_tag=)).to be(true)
      expect(collection.custom_tag).to eq('RubyJobs')
    end
  end

  # 3. Тестування генератора тестових даних (Faker)
  describe WebDataCollector::FakeDataGenerator do
    it 'генерує задану кількість тестових обʼєктів Item' do
      collection = described_class.generate(5)
      expect(collection.size).to eq(5)
      expect(collection.first).to be_a(WebDataCollector::Item)
    end
  end

  # 4. Тестування SQLite: запис у тимчасову БД та перевірка захисту від дублікатів за URL
  describe WebDataCollector::DatabaseConnector do
    it 'зберігає записи у SQLite та запобігає дублікатам за URL' do
      Dir.mktmpdir do |dir|
        db_path = File.join(dir, 'test.sqlite3')
        db = described_class.new(db_path: db_path, table_name: 'test_items')

        item = WebDataCollector::Item.new(title: 'Ruby Dev', company: 'TestCo', url: 'https://example.com/job-1')
        col = WebDataCollector::ItemCollection.new([item, item])

        inserted_first = db.save_collection(col)
        inserted_second = db.save_collection(col)

        expect(inserted_first).to eq(1)
        expect(inserted_second).to eq(0)
        expect(db.total_count).to eq(1)
        expect(db.fetch_all.first.title).to eq('Ruby Dev')
        db.close
      end
    end
  end

  # 5. Тестування експортерів JSON та CSV у тимчасовій директорії
  describe 'Exporters (JSON та CSV)' do
    it 'експортує колекцію у файли JSON та CSV' do
      Dir.mktmpdir do |dir|
        col = WebDataCollector::FakeDataGenerator.generate(3)
        json_path = File.join(dir, 'out.json')
        csv_path = File.join(dir, 'out.csv')

        WebDataCollector::Exporters::JsonExporter.export(col, json_path)
        WebDataCollector::Exporters::CsvExporter.export(col, csv_path)

        expect(File.exist?(json_path)).to be(true)
        expect(JSON.parse(File.read(json_path)).size).to eq(3)
        expect(File.exist?(csv_path)).to be(true)
        expect(File.readlines(csv_path).size).to eq(4)
      end
    end
  end

  # 6. Інтеграційне тестування DSL із підміною парсера через instance_double та перевіркою валідації
  describe 'DSL (PipelineBuilder та PipelineRunner)' do
    it 'побудовує конфігурацію з блоків DSL та виконує конвеєр' do
      Dir.mktmpdir do |dir|
        db_path = File.join(dir, 'dsl.sqlite3')
        json_path = File.join(dir, 'dsl.json')
        csv_path = File.join(dir, 'dsl.csv')

        pipeline = WebDataCollector::PipelineBuilder.new.pipeline('Test DSL') do
          source 'https://example.com/jobs'
          extract card_selector: '.card' do
            field :title, selector: 'h2'
            field :url, selector: 'a', attribute: 'href'
          end
          filter :title do |val|
            val.include?('Ruby')
          end
          save_to :sqlite, db_path: db_path, table: 'dsl_jobs'
          export :json, path: json_path
          export :csv, path: csv_path
        end

        fake_parser = instance_double(
          WebDataCollector::SimpleWebsiteParser,
          parse: WebDataCollector::ItemCollection.new([
            WebDataCollector::Item.new(title: 'Ruby Engineer', url: 'https://example.com/1'),
            WebDataCollector::Item.new(title: 'Python Engineer', url: 'https://example.com/2')
          ])
        )

        result = WebDataCollector::PipelineRunner.new(pipeline, parser: fake_parser).run

        expect(result[:fetched]).to eq(2)
        expect(result[:filtered]).to eq(1)
        expect(result[:saved]).to eq(1)
        expect(File.exist?(json_path)).to be(true)
        expect(File.exist?(csv_path)).to be(true)
      end
    end

    it 'викидає помилку валідації при порожньому source або відсутності полів' do
      invalid_pipeline = WebDataCollector::PipelineBuilder.new.pipeline('Broken') do
        source ''
      end

      expect {
        WebDataCollector::PipelineRunner.new(invalid_pipeline).run
      }.to raise_error(WebDataCollector::PipelineValidationError)
    end
  end
end