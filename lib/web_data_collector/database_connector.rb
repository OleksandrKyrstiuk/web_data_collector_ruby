require 'sqlite3'
require 'fileutils'

module WebDataCollector
  class DatabaseError < StandardError; end

  class DatabaseConnector
    def initialize(db_path:, table_name: 'vacancies', logger: nil)
      @db_path = db_path
      @table_name = validate_table_name!(table_name)
      @logger = logger

      FileUtils.mkdir_p(File.dirname(@db_path))
      @db = SQLite3::Database.new(@db_path)
      @db.results_as_hash = true
      create_table!
    rescue SQLite3::Exception => e
      raise DatabaseError, "Помилка підключення до SQLite (#{@db_path}): #{e.message}"
    end

    # Збереження колекції в одній транзакції з параметризованими запитами та захистом від дублікатів
    def save_collection(collection)
      inserted_count = 0
      sql = <<~SQL
        INSERT OR IGNORE INTO #{@table_name} (title, company, salary, experience, url, scraped_at)
        VALUES (?, ?, ?, ?, ?, ?)
      SQL

      @db.transaction do
        collection.each do |item|
          @db.execute(sql, [item.title, item.company, item.salary, item.experience, item.url, item.scraped_at])
          inserted_count += 1 if @db.changes.positive?
        end
      end

      inserted_count
    rescue SQLite3::Exception => e
      raise DatabaseError, "Помилка збереження записів у БД: #{e.message}"
    end

    # Отримання збережених записів із бази та перетворення їх назад у колекцію ItemCollection
    def fetch_all
      rows = @db.execute("SELECT title, company, salary, experience, url, scraped_at FROM #{@table_name} ORDER BY id DESC")
      collection = ItemCollection.new
      rows.each { |row| collection.add(Item.new(row)) }
      collection
    rescue SQLite3::Exception => e
      raise DatabaseError, "Помилка читання записів із БД: #{e.message}"
    end

    def total_count
      row = @db.get_first_row("SELECT COUNT(*) AS cnt FROM #{@table_name}")
      row ? row['cnt'].to_i : 0
    end

    def close
      @db&.close
    end

    private

    # Перевірка імені таблиці регулярним виразом для захисту від SQL-ін'єкцій
    def validate_table_name!(name)
      raise DatabaseError, "Некоректна назва таблиці: #{name}" unless name.to_s.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)

      name
    end

    def create_table!
      @db.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS #{@table_name} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          company TEXT,
          salary TEXT,
          experience TEXT,
          url TEXT NOT NULL UNIQUE,
          scraped_at TEXT
        );
      SQL
    end
  end
end