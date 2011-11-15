module Insight
  class Logger
    def initialize(level, path)
      @level = level
      @log_path = path
      @logfile = nil
    end

    attr_accessor :level

    DEBUG    =  0
    INFO     =  1
    WARN     =  2
    ERROR    =  3
    FATAL    =  4
    UNKNOWN  =  5

    def log(severity, message)
      if defined? Rails and
        Rails.respond_to? :logger
        not Rails.logger.nil?
        Rails.logger.add(severity, "[Insight]: " + message)
      end

      if severity >= @level
        logfile.puts(message)
      end
    end

    def logfile
      @logfile ||= File::open(@log_path, "a+")
    rescue
      $stderr
    end

    def debug;   log(DEBUG,   yield) end
    def info;    log(INFO,    yield) end
    def warn;    log(WARN,    yield) end
    def error;   log(ERROR,   yield) end
    def fatal;   log(FATAL,   yield) end
    def unknown; log(UNKNOWN, yield) end
  end

  module Logging
    def logger(env = nil)
      if env.nil?
        Thread.current['insight.logger']
      else
        env["insight.logger"]
      end
    end
  end
end
