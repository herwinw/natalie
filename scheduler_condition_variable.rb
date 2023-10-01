#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../ruby/test/fiber/scheduler'

scheduler = Scheduler.new
Fiber.set_scheduler(scheduler)

mutex = Mutex.new
resource = ConditionVariable.new

a = Fiber.new do
  warn("Fiber a: before mutex")
  mutex.synchronize do
    warn("Fiber a: before wait")
    resource.wait(mutex)
    warn("Fiber a: after wait")
  end
  warn("Fiber a: after mutex")
end


b = Fiber.new do
  warn("Fiber b: before mutex")
  mutex.synchronize do
    warn("Fiber b: before signal")
    resource.signal
    warn("Fiber b: after signal")
  end
  warn("Fiber b: after mutex")
end

a.resume
b.resume

scheduler.close
