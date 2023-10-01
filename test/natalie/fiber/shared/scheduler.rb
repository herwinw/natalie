class Scheduler
  def initialize
    @waiting = {}
  end

  def run
    until @waiting.empty?
      fiber, = @waiting.find { |fiber, timeout| fiber.alive? && timeout <= current_time }
      next if fiber.nil?

      @waiting.delete(fiber)
      fiber.resume
    end
  end

  def close
    run
  end

  def kernel_sleep(duration)
    @waiting[Fiber.current] = current_time + duration
    Fiber.yield
  end

  def current_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def io_wait(io, events, duration) end
  def block(blocker, timeout = nil) end
  def unblock(blocker, fiber) end
end
