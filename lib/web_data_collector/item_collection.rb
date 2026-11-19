
module WebDataCollector
  class InvalidItemError < StandardError; end

  class ItemCollection
    include Enumerable

    attr_reader :items

    def initialize(items = [], dynamic_fields: [])
      @items = []
      @dynamic_attributes = {}
      define_dynamic_accessors(*dynamic_fields) unless dynamic_fields.empty?
      items.each { |item| add(item) }
    end

    # Динамічне створення геттерів та сеттерів для конкретного екземпляра колекції
    def define_dynamic_accessors(*fields)
      fields.each do |field|
        attr_name = field.to_sym

        singleton_class.class_eval do
          define_method(attr_name) do
            @dynamic_attributes[attr_name]
          end

          define_method("#{attr_name}=") do |value|
            @dynamic_attributes[attr_name] = value
          end
        end
      end
    end

    def dynamic_attributes
      @dynamic_attributes.dup
    end

    # Контроль типів: колекція приймає виключно об'єкти класу WebDataCollector::Item
    def add(item)
      raise InvalidItemError, "Очікується об'єкт WebDataCollector::Item, отримано #{item.class}" unless item.is_a?(Item)

      @items << item
      self
    end

    alias << add

    def each(&block)
      return enum_for(:each) unless block_given?

      @items.each(&block)
    end

    def size
      @items.size
    end

    alias count size

    def empty?
      @items.empty?
    end

    # Повертає нову відфільтровану або відсортовану колекцію зі збереженням динамічних полів
    def filter_by(&block)
      filtered = select(&block)
      self.class.new(filtered, dynamic_fields: @dynamic_attributes.keys)
    end

    def sort_by_field(field, direction: :asc)
      sorted = @items.sort_by do |item|
        val = item.public_send(field)
        val.is_a?(Numeric) ? val : val.to_s.downcase
      end
      sorted.reverse! if direction == :desc
      self.class.new(sorted, dynamic_fields: @dynamic_attributes.keys)
    end

    def to_export_array
      @items.map(&:to_h)
    end
  end
end