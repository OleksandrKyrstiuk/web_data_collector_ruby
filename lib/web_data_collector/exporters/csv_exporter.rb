require 'csv'
require 'fileutils'

module WebDataCollector
  module Exporters
    class CsvExporter
      def self.export(collection, file_path)
        FileUtils.mkdir_p(File.dirname(file_path))
        headers = Item::ATTRIBUTES

        CSV.open(file_path, 'w', write_headers: true, headers: headers, encoding: 'UTF-8') do |csv|
          collection.each do |item|
            row = item.to_h
            csv << headers.map { |h| row[h] }
          end
        end

        file_path
      end
    end
  end
end
