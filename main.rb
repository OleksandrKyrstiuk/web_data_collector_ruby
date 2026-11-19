require_relative 'lib/web_data_collector'

begin
  engine = WebDataCollector::Engine.new
  engine.run
rescue StandardError => e
  warn "Застосунок завершив роботу з помилкою: #{e.message}"
  exit 1
end
