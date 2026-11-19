# frozen_string_literal: true

require 'time'

module WebDataCollector
  class Item
    # Секція визначення атрибутів сутності та генерації геттерів/сеттерів
    ATTRIBUTES = %i[title company salary experience url scraped_at].freeze
    attr_accessor(*ATTRIBUTES)

    def initialize(attributes = {})
      # Зводимо всі ключі до символів (для сумісності даних із БД та парсера)
      normalized = attributes.transform_keys(&:to_sym)

      @title      = normalized[:title]
      @company    = normalized[:company]
      @salary     = normalized[:salary]
      @experience = normalized[:experience]
      @url        = normalized[:url]
      @scraped_at = normalized[:scraped_at] || Time.now.strftime('%Y-%m-%d %H:%M:%S')
    end

    # Серіалізація: перетворення об'єкта у хеш для експорту в JSON та CSV
    def to_h
      {
        title: @title,
        company: @company,
        salary: @salary,
        experience: @experience,
        url: @url,
        scraped_at: @scraped_at
      }
    end

    def to_s
      "#{@title} | #{@company} | #{@salary || 'ЗП не вказана'} | Досвід: #{@experience} | #{@url}"
    end

    def inspect
      "#<WebDataCollector::Item #{to_h.map { |k, v| "#{k}=#{v.inspect}" }.join(' ')}>"
    end

    # Перевірка еквівалентності двох записів за змістом 
    def ==(other)
      return false unless other.is_a?(Item)

      url == other.url && title == other.title
    end
  end
end