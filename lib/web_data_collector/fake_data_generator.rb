require 'faker'

module WebDataCollector
  class FakeDataGenerator

    ANALYST_TITLES = [
      'Junior Data Analyst',
      'Middle Business Analyst',
      'Senior Product Analyst',
      'BI / SQL Data Analyst',
      'Systems & Data Analyst'
    ].freeze

    EXPERIENCE_LEVELS = ['Без досвіду', '1 рік', '2 роки', '3 роки', '5 років'].freeze

    # Фабричний метод: створює колекцію ItemCollection із динамічними метаданими та заглушками Faker
    def self.generate(count = 10)
      collection = ItemCollection.new([], dynamic_fields: %i[source_name generated_by])
      collection.source_name = 'Djinni (Faker Stub)'
      collection.generated_by = 'WebDataCollector::FakeDataGenerator'

      count.times do |i|
        salary_min = rand(8..45) * 100
        salary_max = salary_min + rand(3..10) * 100

        item = Item.new(
          title: ANALYST_TITLES.sample,
          company: Faker::Company.name,
          salary: "$#{salary_min} - $#{salary_max}",
          experience: EXPERIENCE_LEVELS.sample,
          url: "https://djinni.co/jobs/#{100_000 + i}-#{Faker::Internet.slug(glue: '-')}/"
        )
        collection.add(item)
      end

      collection
    end
  end
end