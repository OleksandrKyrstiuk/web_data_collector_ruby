require 'rspec/core/rake_task'
require_relative 'lib/web_data_collector'

# Реєстрація стандартної задачі для запуску модульних та інтеграційних тестів RSpec
RSpec::Core::RakeTask.new(:spec)

# Задачі запуску основного конвеєра (YAML) та декларативних сценаріїв (DSL)
desc 'Запуск основного конвеєра збору даних (Engine)'
task :run do
  WebDataCollector::Engine.new.run
end

desc 'Запуск DSL-конвеєра (за замовчуванням dsl/djinni_pipeline.rb)'
task :dsl, [:file] do |_t, args|
  dsl_file = args[:file] || 'dsl/djinni_pipeline.rb'
  WebDataCollector::PipelineRunner.run_file(dsl_file)
end

task default: :spec