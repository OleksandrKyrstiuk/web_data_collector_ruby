require 'selenium-webdriver'
require 'nokogiri'
require 'uri'
require 'fileutils'

module WebDataCollector
  class SimpleWebsiteParser
    class ParserError < StandardError; end

    def initialize(url:, selectors_config:, timeout: 15, headless: true, logger: nil)
      @url = url
      @selectors_config = selectors_config || {}
      @timeout = timeout
      @headless = headless
      @logger = logger
      validate_config!
    end

    # Головний метод парсингу: завантажує сторінку через браузер і розбирає HTML у колекцію ItemCollection
    def parse
      html = fetch_html_with_selenium
      parse_html(html)
    end

    private

    def validate_config!
      raise ParserError, 'Не вказано URL для парсингу' if @url.to_s.strip.empty?
      raise ParserError, 'Відсутня конфігурація селекторів для сайту' if @selectors_config.empty?
      raise ParserError, 'Не вказано селектор картки елемента (item_card)' if @selectors_config['item_card'].to_s.strip.empty?
    end

    # Налаштування Chrome WebDriver (headless-режим для фонової роботи та приховування ознак автоматизації)
    def build_driver
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument('--headless=new') if @headless
      options.add_argument('--disable-gpu')
      options.add_argument('--no-sandbox')
      options.add_argument('--disable-dev-shm-usage')
      options.add_argument('--disable-blink-features=AutomationControlled')
      options.add_argument('--window-size=1920,1080')
      options.add_argument('--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36')

      driver = Selenium::WebDriver.for(:chrome, options: options)
      driver.manage.timeouts.page_load = @timeout
      driver
    end

    # Отримання відрендереного DOM-дерева з явним очікуванням появи карток та гарантованим закриттям браузера
    def fetch_html_with_selenium
      driver = nil
      @logger&.info("Запуск Selenium WebDriver (headless=#{@headless}) для завантаження #{@url}")
      driver = build_driver
      driver.navigate.to(@url)

      wait = Selenium::WebDriver::Wait.new(timeout: @timeout)
      card_selector = @selectors_config['item_card']
      begin
        wait.until { !driver.find_elements(css: card_selector).empty? }
      rescue Selenium::WebDriver::Error::TimeoutError
        @logger&.warn("Час очікування (#{@timeout} с) вичерпано для селектора '#{card_selector}'. Заголовок сторінки: '#{driver.title}'")
      end

      driver.page_source
    rescue Selenium::WebDriver::Error::WebDriverError, SocketError, StandardError => e
      raise ParserError, "Помилка завантаження сторінки через Selenium (#{@url}): #{e.message}"
    ensure
      driver&.quit
    end

    # Розбір HTML через Nokogiri та формування об'єктів Item
    def parse_html(html)
      doc = Nokogiri::HTML(html)
      card_selector = @selectors_config['item_card']
      fields_config = @selectors_config['fields'] || {}

      cards = doc.css(card_selector)
      collection = ItemCollection.new([], dynamic_fields: %i[source_name parsed_by])
      collection.source_name = @url
      collection.parsed_by = self.class.name

      if cards.empty?
        FileUtils.mkdir_p('logs')
        File.write('logs/debug_page.html', html, encoding: 'UTF-8')
        @logger&.warn("За селектором '#{card_selector}' елементів не знайдено. HTML збережено у logs/debug_page.html (title: '#{doc.title.strip}')")
        return collection
      end

      cards.each do |card|
        attributes = extract_fields(card, fields_config)
        next if attributes[:title].to_s.strip.empty?

        collection.add(Item.new(attributes))
      end

      collection
    end

    def extract_fields(card, fields_config)
      fields_config.each_with_object({}) do |(field_name, rule), result|
        selector = rule['selector']
        attr_type = rule['attribute'] || 'text'
        element = card.at_css(selector)

        if element.nil?
          result[field_name.to_sym] = nil
          next
        end

        raw_value = if attr_type == 'text'
                      element.text.gsub(/\s+/, ' ').strip
                    else
                      element[attr_type].to_s.strip
                    end

        result[field_name.to_sym] = normalize_value(field_name.to_s, raw_value)
      end
    end

    def normalize_value(field_name, value)
      return nil if value.empty?
      return URI.join(@url, value).to_s if field_name == 'url' && value.start_with?('/')

      value
    rescue URI::InvalidURIError
      value
    end
  end
end