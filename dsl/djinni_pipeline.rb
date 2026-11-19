pipeline 'бір Ruby-вакансій із Djinni' do
  source 'https://djinni.co/jobs/?primary_keyword=Ruby'

  extract card_selector: "div.job-item[id^='job-item-']" do
    field :title, selector: 'h2.job-item__position', attribute: 'text'
    field :url, selector: 'a.job_item__header-link', attribute: 'href'
    field :company, selector: 'header .col span.small', attribute: 'text'
    field :salary, selector: 'span.text-success, .public-salary-item', attribute: 'text'
    field :experience, selector: 'div.fw-medium span.text-nowrap, span.text-nowrap', attribute: 'text'
  end

  filter :title do |value|
    !value.to_s.strip.empty?
  end

  save_to :sqlite, db_path: 'data/jobs.sqlite3', table: 'dsl_vacancies'
  export :json, path: 'output/dsl_vacancies.json'
  export :csv, path: 'output/dsl_vacancies.csv'
end
