require 'zeitwerk'

module WebDataCollector
  loader = Zeitwerk::Loader.new
  loader.push_dir(__dir__)
  loader.setup
end