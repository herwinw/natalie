require_relative '../../spec_helper'
require_relative 'fixtures/classes'

describe :kernel_system, shared: true do
  it "executes the specified command in a subprocess" do
    NATFIXME 'it executes the specified command in a subprocess', exception: SpecFailedException do
      -> { @object.system("echo a") }.should output_to_fd("a\n")
    end

    $?.should be_an_instance_of Process::Status
    $?.should.success?
  end

  it "returns true when the command exits with a zero exit status" do
    @object.system(ruby_cmd('exit 0')).should == true

    $?.should be_an_instance_of Process::Status
    $?.should.success?
    $?.exitstatus.should == 0
  end

  it "returns false when the command exits with a non-zero exit status" do
    @object.system(ruby_cmd('exit 1')).should == false

    $?.should be_an_instance_of Process::Status
    $?.should_not.success?
    $?.exitstatus.should == 1
  end

  it "raises RuntimeError when `exception: true` is given and the command exits with a non-zero exit status" do
    NATFIXME 'it raises RuntimeError when `exception: true` is given and the command exits with a non-zero exit status', exception: SpecFailedException do
      -> { @object.system(ruby_cmd('exit 1'), exception: true) }.should raise_error(RuntimeError)
    end
  end

  it "raises Errno::ENOENT when `exception: true` is given and the specified command does not exist" do
    NATFIXME 'it raises Errno::ENOENT when `exception: true` is given and the specified command does not exist', exception: SpecFailedException do
      -> { @object.system('feature_14386', exception: true) }.should raise_error(Errno::ENOENT)
    end
  end

  it "returns nil when command execution fails" do
    @object.system("sad").should be_nil

    $?.should be_an_instance_of Process::Status
    $?.pid.should be_kind_of(Integer)
    $?.should_not.success?
  end

  it "does not write to stderr when command execution fails" do
    -> { @object.system("sad") }.should output_to_fd("", STDERR)
  end

  platform_is_not :windows do
    before :each do
      @shell = ENV['SHELL']
    end

    after :each do
      ENV['SHELL'] = @shell
    end

    it "executes with `sh` if the command contains shell characters" do
      NATFIXME 'it executes with `sh` if the command contains shell characters', exception: SpecFailedException do
        -> { @object.system("echo $0") }.should output_to_fd("sh\n")
      end
    end

    it "ignores SHELL env var and always uses `sh`" do
      ENV['SHELL'] = "/bin/fakeshell"
      NATFIXME 'it ignores SHELL env var and always uses `sh`', exception: SpecFailedException do
        -> { @object.system("echo $0") }.should output_to_fd("sh\n")
      end
    end
  end

  platform_is_not :windows do
    before :each do
      require 'tmpdir'
      @shell_command = File.join(Dir.mktmpdir, "noshebang.cmd")
      File.write(@shell_command, %[echo "$PATH"\n], perm: 0o700)
    end

    after :each do
      File.unlink(@shell_command)
      Dir.rmdir(File.dirname(@shell_command))
    end

    it "executes with `sh` if the command is executable but not binary and there is no shebang" do
      NATFIXME 'it executes with `sh` if the command is executable but not binary and there is no shebang', exception: SpecFailedException do
        -> { @object.system(@shell_command) }.should output_to_fd(ENV['PATH'] + "\n")
      end
    end
  end

  before :each do
    ENV['TEST_SH_EXPANSION'] = 'foo'
    @shell_var = '$TEST_SH_EXPANSION'
    platform_is :windows do
      @shell_var = '%TEST_SH_EXPANSION%'
    end
  end

  after :each do
    ENV.delete('TEST_SH_EXPANSION')
  end

  it "expands shell variables when given a single string argument" do
    NATFIXME 'it expands shell variables when given a single string argument', exception: SpecFailedException do
      -> { @object.system("echo #{@shell_var}") }.should output_to_fd("foo\n")
    end
  end

  platform_is_not :windows do
    it "does not expand shell variables when given multiples arguments" do
      NATFIXME 'it does not expand shell variables when given multiples arguments', exception: SpecFailedException do
        -> { @object.system("echo", @shell_var) }.should output_to_fd("#{@shell_var}\n")
      end
    end
  end

  platform_is :windows do
    it "does expand shell variables when given multiples arguments" do
      # See https://bugs.ruby-lang.org/issues/12231
      -> { @object.system("echo", @shell_var) }.should output_to_fd("foo\n")
    end
  end

  platform_is :windows do
    it "runs commands starting with any number of @ using shell" do
      `#{ruby_cmd("p system 'does_not_exist'")} 2>NUL`.chomp.should == "nil"
      @object.system('@does_not_exist 2>NUL').should == false
      @object.system("@@@#{ruby_cmd('exit 0')}").should == true
    end
  end
end

describe "Kernel#system" do
  it "is a private method" do
    Kernel.should have_private_instance_method(:system)
  end

  it_behaves_like :kernel_system, :system, KernelSpecs::Method.new
end

describe "Kernel.system" do
  it_behaves_like :kernel_system, :system, Kernel
end
