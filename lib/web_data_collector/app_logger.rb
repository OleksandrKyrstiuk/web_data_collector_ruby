require 'logger'
require 'fileutils'

module WebDataCollector
  class AppLogger
    class MultiIO
      def initialize(*targets)
        @targets = targets
      end

      def write(*args)
        @targets.each { |t| t.write(*args) }
      end

      def close
        @targets.each { |t| t.close unless t == $stdout || t == $stderr }
      end
    end

    # Налаштовання стандартного Logger із рівнем деталізації та форматом дати
    def self.build(log_dir: 'logs', level: 'info')
      FileUtils.mkdir_p(log_dir)
      log_file = File.open(File.join(log_dir, 'app.log'), 'a')
      log_file.sync = true

      logger = Logger.new(MultiIO.new(log_file, $stdout))
      logger.level = Logger.const_get(level.to_s.upcase)
      logger.formatter = proc do |severity, datetime, _progname, msg|
        "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
      end
      logger
    end
  end
end