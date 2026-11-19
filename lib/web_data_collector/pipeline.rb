module WebDataCollector
  class Pipeline
    attr_accessor :name, :source_url, :card_selector, :fields, :filters, :storage, :exports

    def initialize(name)
      @name = name
      @source_url = nil
      @card_selector = "div.job-item[id^='job-item-']"
      @fields = {}
      @filters = []
      @storage = nil
      @exports = []
    end
  end
end
