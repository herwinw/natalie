# frozen_string_literal: false

# Mix in to add reentrant monitor behavior to a class. Implemented on top of
# Mutex and Thread::ConditionVariable.
module MonitorMixin
  def self.extend_object(obj)
    super(obj)
    obj.__send__(:mon_initialize)
  end

  def try_enter
    if @mon_owner == Thread.current
      @mon_count += 1
      true
    elsif @mon_mutex.try_lock
      @mon_owner = Thread.current
      @mon_count = 1
      true
    else
      false
    end
  end

  def enter
    if @mon_owner == Thread.current
      @mon_count += 1
    else
      @mon_mutex.lock
      @mon_owner = Thread.current
      @mon_count = 1
    end
    nil
  end

  def exit
    mon_check_owner
    @mon_count -= 1
    if @mon_count == 0
      @mon_owner = nil
      @mon_mutex.unlock
    end
    nil
  end

  def mon_locked?
    @mon_mutex.locked?
  end

  def mon_owned?
    @mon_owner == Thread.current
  end

  def mon_check_owner
    raise ThreadError, 'current thread not owner' if @mon_owner != Thread.current
  end

  def synchronize
    enter
    begin
      yield
    ensure
      exit
    end
  end

  def new_cond
    ConditionVariable.new(self)
  end

  def wait_for_cond(cond, timeout)
    mon_check_owner
    count = @mon_count
    @mon_owner = nil
    @mon_count = 0
    begin
      cond.wait(@mon_mutex, timeout)
    ensure
      @mon_owner = Thread.current
      @mon_count = count
    end
    true
  end

  class ConditionVariable
    def initialize(monitor)
      @monitor = monitor
      @cond = Thread::ConditionVariable.new
    end

    def wait(timeout = nil)
      @monitor.wait_for_cond(@cond, timeout)
    end

    def wait_until
      wait until yield
    end

    def wait_while
      wait while yield
    end

    def signal
      @cond.signal
    end

    def broadcast
      @cond.broadcast
    end
  end

  private

  def initialize(...)
    super
    mon_initialize
  end

  def mon_initialize
    @mon_mutex = Mutex.new
    @mon_owner = nil
    @mon_count = 0
  end
end

class Monitor
  include MonitorMixin
end
