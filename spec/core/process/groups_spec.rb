require_relative '../../spec_helper'

describe "Process.groups" do
  platform_is_not :windows do
    it "gets an Array of the gids of groups in the supplemental group access list" do
      groups = `id -G`.scan(/\d+/).map { |i| i.to_i }
      # Include the standard `id` command output.  On macOS, GNU
      # coreutils `id` is limited to NGROUPS_MAX groups, because of
      # the backward compatibility of getgroups(2).
      (groups |= `/usr/bin/id -G`.split(/\s+/).map { |i| i.to_i }) rescue nil
      gid = Process.gid

      expected = (groups.sort - [gid]).uniq.sort
      actual = (Process.groups - [gid]).uniq.sort
      actual.should == expected
    end
  end
end

describe "Process.groups=" do
  platform_is_not :windows, :android do
    as_superuser do
      it "sets the list of gids of groups in the supplemental group access list" do
        NATFIXME 'Implement Process#groups=', exception: NoMethodError, message: "undefined method 'groups='" do
          groups = Process.groups
          Process.groups = []
          Process.groups.should == []
          Process.groups = groups
          Process.groups.sort.should == groups.sort
        end
      end
    end

    as_user do
      platform_is :aix do
        it "sets the list of gids of groups in the supplemental group access list" do
          # setgroups() is not part of the POSIX standard,
          # so its behavior varies from OS to OS.  AIX allows a non-root
          # process to set the supplementary group IDs, as long as
          # they are presently in its supplementary group IDs.
          # The order of the following tests matters.
          # After this process executes "Process.groups = []"
          # it should no longer be able to set any supplementary
          # group IDs, even if it originally belonged to them.
          # It should only be able to set its primary group ID.
          groups = Process.groups
          Process.groups = groups
          Process.groups.sort.should == groups.sort
          Process.groups = []
          Process.groups.should == []
          Process.groups = [ Process.gid ]
          Process.groups.should == [ Process.gid ]
          supplementary = groups - [ Process.gid ]
          if supplementary.length > 0
            -> { Process.groups = supplementary }.should raise_error(Errno::EPERM)
          end
        end
      end

      platform_is_not :aix do
        it "raises Errno::EPERM" do
          NATFIXME 'Implement Process#groups=', exception: SpecFailedException do
            -> {
              Process.groups = [0]
            }.should raise_error(Errno::EPERM)
          end
        end
      end
    end
  end
end
