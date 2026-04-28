require 'natalie/inline'
require 'syslog.cpp'

module Syslog
  VERSION = '0.3.0'.freeze

  module Option
    __constant__('LOG_PID', 'int')
    __constant__('LOG_CONS', 'int')
    __constant__('LOG_ODELAY', 'int')
    __constant__('LOG_NDELAY', 'int')
    __constant__('LOG_NOWAIT', 'int')
    __constant__('LOG_PERROR', 'int')
  end

  module Facility
    __constant__('LOG_AUTH', 'int')
    __constant__('LOG_AUTHPRIV', 'int')
    __constant__('LOG_CONSOLE', 'int')
    __constant__('LOG_CRON', 'int')
    __constant__('LOG_DAEMON', 'int')
    __constant__('LOG_FTP', 'int')
    __constant__('LOG_KERN', 'int')
    __constant__('LOG_LPR', 'int')
    __constant__('LOG_MAIL', 'int')
    __constant__('LOG_NEWS', 'int')
    __constant__('LOG_NTP', 'int')
    __constant__('LOG_SECURITY', 'int')
    __constant__('LOG_SYSLOG', 'int')
    __constant__('LOG_USER', 'int')
    __constant__('LOG_UUCP', 'int')
    __constant__('LOG_LOCAL0', 'int')
    __constant__('LOG_LOCAL1', 'int')
    __constant__('LOG_LOCAL2', 'int')
    __constant__('LOG_LOCAL3', 'int')
    __constant__('LOG_LOCAL4', 'int')
    __constant__('LOG_LOCAL5', 'int')
    __constant__('LOG_LOCAL6', 'int')
    __constant__('LOG_LOCAL7', 'int')
  end

  module Level
    __constant__('LOG_EMERG', 'int')
    __constant__('LOG_ALERT', 'int')
    __constant__('LOG_CRIT', 'int')
    __constant__('LOG_ERR', 'int')
    __constant__('LOG_WARNING', 'int')
    __constant__('LOG_NOTICE', 'int')
    __constant__('LOG_INFO', 'int')
    __constant__('LOG_DEBUG', 'int')
  end

  module Macros
    __bind_method__ :LOG_MASK, :Syslog_LOG_MASK, 1
    __bind_method__ :LOG_UPTO, :Syslog_LOG_UPTO, 1
  end

  module Constants
    include Option
    include Facility
    include Level
    extend Macros
  end

  include Constants
  extend Macros

  __bind_static_method__ :open, :Syslog_open
  __bind_static_method__ :reopen, :Syslog_reopen
  __bind_static_method__ :open!, :Syslog_reopen
  __bind_static_method__ :opened?, :Syslog_opened, 0
  __bind_static_method__ :ident, :Syslog_ident, 0
  __bind_static_method__ :options, :Syslog_options, 0
  __bind_static_method__ :facility, :Syslog_facility, 0
  __bind_static_method__ :close, :Syslog_close, 0
  __bind_static_method__ :instance, :Syslog_instance, 0
  __bind_static_method__ :log, :Syslog_log
  __bind_static_method__ :emerg, :Syslog_emerg
  __bind_static_method__ :alert, :Syslog_alert
  __bind_static_method__ :crit, :Syslog_crit
  __bind_static_method__ :err, :Syslog_err
  __bind_static_method__ :warning, :Syslog_warning
  __bind_static_method__ :notice, :Syslog_notice
  __bind_static_method__ :info, :Syslog_info
  __bind_static_method__ :debug, :Syslog_debug
end
