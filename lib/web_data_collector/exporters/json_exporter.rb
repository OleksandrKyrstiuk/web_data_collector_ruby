require 'json'
require 'fileutils'

module WebDataCollector
  module Exporters
    class JsonExporter
      def self.export(collection, file_path)
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, JSON.pretty_generate(collection.to_export_array), encoding: 'UTF-8')
        file_path
      end
    end
  end
end
