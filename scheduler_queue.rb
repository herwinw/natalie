#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../ruby/test/fiber/scheduler'

scheduler = Scheduler.new
Fiber.set_scheduler(scheduler)

q = Queue.new

consumer = Fiber.new do
  warn("Starting consumer")
  value = q.pop
  warn("Finished consumer: #{value}")
end

producer = Fiber.new do
  warn("Starting producer")
  q.push(:fiber_scheduler)
  warn("Finished producer")
end

consumer.resume
producer.resume
