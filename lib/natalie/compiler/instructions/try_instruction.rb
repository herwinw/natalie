require_relative './base_instruction'

module Natalie
  class Compiler
    class TryInstruction < BaseInstruction
      attr_reader :serial, :has_ensure

      def initialize(discard_catch_result: false, has_ensure: false)
        @discard_catch_result = discard_catch_result
        @has_ensure = has_ensure
        @serial = self.class.serial
      end

      def to_s
        s = 'try'
        s << ' (discard_catch_result)' if @discard_catch_result
        s << ' (ensure)' if @has_ensure
        s
      end

      def has_body?
        true
      end

      def generate(transform)
        body = transform.fetch_block_of_instructions(until_instruction: CatchInstruction)
        catch_body = transform.fetch_block_of_instructions(expected_label: :try) # or else or ensure?
        result = transform.temp('try_result')
        code = []

        has_retry = catch_body.detect { |i| i.is_a?(RetryInstruction) }

        # hoisted variables need to be set to nil here
        (@env[:hoisted_vars] || {}).each do |_, var|
          code << "Value #{var.fetch(:name)} = Value::nil()"
          var[:declared] = true
        end

        code << "Value #{result}"

        if has_retry
          code << "bool #{retry_name}"
          code << 'do {'
          code << "#{retry_name} = false"
        end

        transform.normalize_stack do
          code << 'try {'
          transform.with_same_scope(body) { |t| code << t.transform("#{result} =") }

          code << 'GlobalEnv::the()->set_rescued(false);'
          code << '} catch(ExceptionObject *exception) {'

          code << 'auto exception_was = env->exception()'
          # The Defer ensures $! is restored even when the catch body itself
          # throws (e.g. a `return` from inside rescue, which propagates via
          # LocalJumpError so a surrounding ensure can run).
          code << 'Defer restore_exception([&] { env->set_exception(exception_was); })'
          if @has_ensure
            # Ensure-only try: control-flow throws (LocalJumpError from
            # `return`, `break`, etc.) must not clobber $! while the ensure
            # body runs; only real Ruby exceptions become the new $!.
            code << 'if (exception->local_jump_error_type() == LocalJumpErrorType::None) env->set_exception(exception)'
          else
            code << 'env->set_exception(exception)'
          end

          transform.with_same_scope(catch_body) { |t| code << t.transform(@discard_catch_result ? nil : "#{result} =") }

          code << 'GlobalEnv::the()->set_rescued(true)'

          # For an ensure-only try the catch body just runs the ensure clause;
          # the original exception (whether a real Ruby exception or a
          # control-flow LocalJumpError) must propagate up after that.
          code << 'throw exception' if @has_ensure

          code << '}'
        end

        code << "} while (#{retry_name})" if has_retry

        transform.exec(code)
        transform.push(result)
      end

      def execute(vm)
        start_ip = vm.ip
        vm.skip_block_of_instructions(until_instruction: CatchInstruction)
        catch_ip = vm.ip
        vm.skip_block_of_instructions(expected_label: :try)
        end_ip = vm.ip
        begin
          vm.ip = start_ip
          vm.run
          vm.ip = end_ip
          vm.rescued = false
        rescue => e
          vm.rescued = true
          exception_was = vm.global_variables[:$!]
          # For an ensure-only try, control-flow throws (LocalJumpError from
          # `return`, `break`, etc.) must not clobber $! while the ensure body
          # runs; only real Ruby exceptions become the new $!.
          vm.global_variables[:$!] = e unless @has_ensure && e.is_a?(LocalJumpError)
          vm.ip = catch_ip
          vm.run
          vm.ip = end_ip
          if exception_was
            vm.global_variables[:$!] = exception_was
          else
            vm.global_variables.delete(:$!)
          end
          # The catch body for an ensure-only try just runs the ensure clause;
          # the original exception must propagate up after that. (For a rescue
          # try, the catch body itself raises if no clause matched.)
          raise e if @has_ensure
        end
      end

      @serial = 0

      def self.serial
        @serial += 1
      end

      private

      def retry_name
        "should_retry_#{serial}"
      end
    end
  end
end
