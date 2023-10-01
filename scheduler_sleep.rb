#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../ruby/test/fiber/scheduler'

scheduler = Scheduler.new
Fiber.set_scheduler(scheduler)

consumer = Fiber.new do
  warn("Starting consumer")
  sleep(0.01)
  warn("Finished consumer")
end

producer = Fiber.new do
  warn("Running producer")
end

consumer.resume
producer.resume
