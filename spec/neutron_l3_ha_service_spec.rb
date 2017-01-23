require 'open3'
require 'fileutils'
require 'tmpdir'


class RunResult
  attr_reader :stdout, :stderr, :exitstatus

  def initialize(stdout, stderr, exit_status)
    @stdout = stdout
    @stderr = stderr
    @exitstatus = exit_status
  end
end


class NeutronServiceScript
  attr_writer :rcfile_path

  def run
    this_dir = File.dirname(__FILE__)
    script_path = File.join(
      this_dir,
      '..',
      'chef/cookbooks/neutron/files/default/neutron-l3-ha-service'
    )
    args = [script_path]
    args += [@rcfile_path] if @rcfile_path
    Open3.popen3('/bin/sh', *args) do
    |stdin, stdout, stderr, wait_thr|
      stdin.close
      stdout_bytes = stdout.read
      stderr_bytes = stderr.read
      exitstatus = wait_thr.value.exitstatus
      RunResult.new(stdout_bytes, stderr_bytes, exitstatus)
    end
  end
end


def test_neutron_service
  Dir.mktmpdir do |tmpdir|
    yield NeutronServiceScript.new, Tmpdir.new(tmpdir)
  end
end


def make_rcfile(neutron_service_script, tmpdir, hatool_path)
  # Create an rcfile that meets basic requirements of the neutron_service_script script.
  # Please also note that it includes NHAS_DEBUG_ONESHOT which breaks out
  # from the infinite loop.
  neutron_service_script.rcfile_path = tmpdir.write_file 'rcfile.sh', <<-EOF
      #!/bin/sh
      export OS_AUTH_URL=1
      export OS_REGION_NAME=1
      export OS_TENANT_NAME=1
      export OS_USERNAME=1
      export OS_INSECURE=1
      NHAS_SECONDS_TO_SLEEP_BETWEEN_CHECKS=1
      NHAS_AGENT_CHECK_TIMEOUT=1
      NHAS_AGENT_CHECK_SHUTDOWN_TIMEOUT=1
      NHAS_REPLICATE_DHCP_TIMEOUT=1
      NHAS_REPLICATE_DHCP_SHUTDOWN_TIMEOUT=1
      NHAS_AGENT_MIGRATE_TIMEOUT=1
      NHAS_AGENT_MIGRATE_SHUTDOWN_TIMEOUT=1
      NHAS_HA_TOOL=#{hatool_path}
      NHAS_DEBUG_ONESHOT=1
  EOF
end


class Tmpdir
  # Helper class for easily creating files and getting their contents
  # within a root directory.
  def initialize(root_path)
    @root_path = root_path
  end

  def path_for(basename)
    File.join(@root_path, basename)
  end

  def write_file(basename, contents)
    full_path = path_for(basename)
    File.open(full_path, 'w') do |script|
      script.write contents
    end
    full_path
  end

  def write_script(basename, content)
    full_path = write_file basename, content
    FileUtils.chmod 0700, full_path
    full_path
  end

  def contents_of(basename)
    File.open path_for(basename) do |file|
      file.read
    end
  end
end


describe NeutronServiceScript do
  context 'without rcfile specified' do
    before(:each) do
      @neutron_service_script = NeutronServiceScript.new
    end

    it 'exits with 1' do
      run_result = @neutron_service_script.run
      expect(run_result.exitstatus).to eq 1
    end

    it 'error message complains about missing rc file' do
      run_result = @neutron_service_script.run
      expect(run_result.stderr).to include 'Please specify an rc file as the first argument for the script'
    end

  end

  context 'with non existing rcfile specified' do
    around(:each) do |example|
      test_neutron_service do |neutron_service_script, tmpdir|
        @neutron_service_script = neutron_service_script
        @neutron_service_script.rcfile_path = tmpdir.path_for 'nonexisting'
        example.run
      end
    end

    it 'displays correct error message' do
      run_result = @neutron_service_script.run
      expect(run_result.stderr).to include 'ERROR: Specified rc file does not exist'
    end

    it 'exits with 1' do
      run_result = @neutron_service_script.run
      expect(run_result.exitstatus).to eq 1
    end

  end

  context 'with existing rcfile' do
    around(:each) do |example|
      test_neutron_service do |neutron_service_script, tmpdir|
        @neutron_service_script = neutron_service_script
        @tmpdir = tmpdir
        logpath = tmpdir.path_for 'log'
        neutron_service_script.rcfile_path = tmpdir.write_file 'rcfile.sh', <<-EOF
        echo "executed" >>#{logpath}
        EOF
        example.run
      end
    end

    it 'sources existing rcfile' do
      run_result = @neutron_service_script.run

      expect(@tmpdir.contents_of 'log').to eq <<-EOF.gsub /^\s+/, ""
      executed
      EOF
    end

    it 'error message complains about missing export' do
      run_result = @neutron_service_script.run
      expect(run_result.stderr).to include 'environment variable OS_AUTH_URL is not exported'
    end

    it 'exits with 1' do
      run_result = @neutron_service_script.run
      expect(run_result.exitstatus).to eq 1
    end
  end

  context 'rcfile missing local vars' do
    around(:each) do |example|
      test_neutron_service do |neutron_service_script, tmpdir|
        @neutron_service_script = neutron_service_script
        @tmpdir = tmpdir
        neutron_service_script.rcfile_path = @tmpdir.write_file 'rcfile.sh', <<-EOF
        export OS_AUTH_URL=1
        export OS_REGION_NAME=1
        export OS_TENANT_NAME=1
        export OS_USERNAME=1
        export OS_INSECURE=1
        EOF
        example.run
      end
    end

    it 'error message complains about missing vairable' do
      run_result = @neutron_service_script.run
      expect(run_result.stderr).to include 'environment variable NHAS_SECONDS_TO_SLEEP_BETWEEN_CHECKS is not set'
    end

    it 'exits with 1' do
      run_result = @neutron_service_script.run
      expect(run_result.exitstatus).to eq 1
    end
  end

  context 'nonexisting hatool' do
    around(:each) do |example|
      test_neutron_service do |neutron_service_script, tmpdir|
        @neutron_service_script = neutron_service_script
        hatool_path = tmpdir.path_for 'hatool.sh'
        make_rcfile neutron_service_script, tmpdir, hatool_path
        example.run
      end
    end

    it 'prints out an error message' do
      run_result = @neutron_service_script.run
      expect(run_result.stderr).to include 'neutron-ha-tool is not a regular file'
    end

    it 'exits with 1' do
      run_result = @neutron_service_script.run
      expect(run_result.exitstatus).to eq 1
    end
  end

  context 'non executable hatool' do
    around(:each) do |example|
      test_neutron_service do |neutron_service_script, tmpdir|
        @neutron_service_script = neutron_service_script
        hatool_path = tmpdir.write_file 'hatool.sh', <<-EOF
        #!/bin/sh
        echo "HELLO"
        EOF
        make_rcfile neutron_service_script, tmpdir, hatool_path
        example.run
      end
    end

    it 'prints out an error message' do
      run_result = @neutron_service_script.run

      expect(run_result.stderr).to include 'neutron-ha-tool not executable'
    end

    it 'exits with 1' do
      run_result = @neutron_service_script.run
      expect(run_result.exitstatus).to eq 1
    end
  end

  context 'when l3 agent check returns 0' do
    around(:each) do |example|
      test_neutron_service do |neutron_service_script, tmpdir|
        @neutron_service_script = neutron_service_script
        @tmpdir = tmpdir
        logpath = tmpdir.path_for 'log'
        hatool_path = tmpdir.write_script 'hatool.sh', <<-EOF
        #!/bin/sh
        echo "$@" >>#{logpath}
        EOF
        make_rcfile neutron_service_script, tmpdir, hatool_path
        example.run
      end
    end

    it 'makes only one check call' do
      @neutron_service_script.run

      expect(@tmpdir.contents_of 'log').to eq <<-EXPECTED.gsub /^\s+/, ""
      --help
      --l3-agent-check --quiet --insecure
      EXPECTED
    end
  end

  context 'when l3 agent check returns 2' do
    around(:each) do |example|
      test_neutron_service do |neutron_service_script, tmpdir|
        @neutron_service_script = neutron_service_script
        @tmpdir = tmpdir
        logpath = tmpdir.path_for 'log'
        hatool_path = tmpdir.write_script 'hatool.sh', <<-EOF
        #!/bin/sh
        echo "$@" >>#{logpath}
        if echo "$@" | grep -q -- --l3-agent-check; then
          exit 2
        fi
        EOF
        make_rcfile neutron_service_script, tmpdir, hatool_path
        example.run
      end
    end

    it 'calls neutron-ha-tool for dhcp replication and migration' do
      @neutron_service_script.run

      expect(@tmpdir.contents_of 'log').to eq <<-EXPECTED.gsub /^\s+/, ""
      --help
      --l3-agent-check --quiet --insecure
      --replicate-dhcp --insecure
      --l3-agent-migrate --now --insecure
      EXPECTED
    end
  end

  context 'when l3 agent check returns 2 and hatool reports retry' do
    around(:each) do |example|
      test_neutron_service do |neutron_service_script, tmpdir|
        @neutron_service_script = neutron_service_script
        @tmpdir = tmpdir
        logpath = tmpdir.path_for 'log'
        hatool_path = tmpdir.write_script 'hatool.sh', <<-EOF
        #!/bin/sh
        echo "$@" >>#{logpath}
        if echo "$@" | grep -q -- --help; then
          echo "--retry"
        fi
        if echo "$@" | grep -q -- --l3-agent-check; then
          exit 2
        fi
        EOF
        make_rcfile neutron_service_script, tmpdir, hatool_path
        example.run
      end
    end

    it 'calls neutron-ha-tool for dhcp replication and migration with retry' do
      @neutron_service_script.run

      expect(@tmpdir.contents_of 'log').to eq <<-EXPECTED.gsub /^\s+/, ""
      --help
      --l3-agent-check --quiet --insecure
      --replicate-dhcp --retry --insecure
      --l3-agent-migrate --retry --now --insecure
      EXPECTED
    end
  end

  context 'when l3 agent check times out' do
    around(:each) do |example|
      test_neutron_service do |neutron_service_script, tmpdir|
        @neutron_service_script = neutron_service_script
        @tmpdir = tmpdir
        hatool_path = tmpdir.write_script 'hatool.sh', <<-EOF
        #!/bin/sh
        echo "$@" >>#{tmpdir.path_for 'log'}
        term_signal_received() {
            echo "term" >> #{tmpdir.path_for 'signals'}
        }
        trap term_signal_received TERM

        if echo "$@" | grep -q -- --l3-agent-check; then
          sleep 20
        fi
        EOF
        make_rcfile neutron_service_script, tmpdir, hatool_path
        example.run
      end
    end

    it 'does not call dhcp replication or router migration' do
      @neutron_service_script.run

      expect(@tmpdir.contents_of 'log').to eq <<-EXPECTED.gsub /^\s+/, ""
      --help
      --l3-agent-check --quiet --insecure
      EXPECTED
    end

    it 'carries on with the main loop' do
      run_result = @neutron_service_script.run

      expect(run_result.exitstatus).to eq 3
    end

    it 'term signal is sent to ha-tool' do
      @neutron_service_script.run

      expect(@tmpdir.contents_of 'signals').to eq <<-EXPECTED.gsub /^\s+/, ""
      term
      EXPECTED
    end
  end

  context 'when replicate dhcp times out' do
    around(:each) do |example|
      test_neutron_service do |neutron_service_script, tmpdir|
        @neutron_service_script = neutron_service_script
        @tmpdir = tmpdir
        logpath = tmpdir.path_for 'log'
        hatool_path = tmpdir.write_script 'hatool.sh', <<-EOF
        #!/bin/sh
        echo "$@" >>#{logpath}
        if echo "$@" | grep -q -- --l3-agent-check; then
          exit 2
        fi
        if echo "$@" | grep -q -- --replicate-dhcp; then
          sleep 4
        fi
        EOF
        make_rcfile neutron_service_script, tmpdir, hatool_path
        example.run
      end
    end

    it 'dies with timeout error code and message' do
      run_result = @neutron_service_script.run

      expect(run_result.exitstatus).to eq 143
      expect(run_result.stderr).to include 'call timed out'
    end
  end

  context 'when replicate dhcp times out gracefully' do
    around(:each) do |example|
      test_neutron_service do |neutron_service_script, tmpdir|
        @neutron_service_script = neutron_service_script
        @tmpdir = tmpdir
        hatool_path = tmpdir.write_script 'hatool.sh', <<-EOF
        #!/bin/sh
        echo "$@" >>#{tmpdir.path_for 'log'}
        term_signal_received() {
            echo "term" >> #{tmpdir.path_for 'signals'}
            exit 100
        }
        trap term_signal_received TERM 
    
        if echo "$@" | grep -q -- --l3-agent-check; then
          exit 2
        fi
        if echo "$@" | grep -q -- --replicate-dhcp; then
          sleep 4
        fi
        EOF
        make_rcfile neutron_service_script, tmpdir, hatool_path
        example.run
      end
    end

    it 'dies with error code from script' do
      run_result = @neutron_service_script.run

      expect(run_result.exitstatus).to eq 100
      expect(run_result.stderr).to include 'call failed'
    end

    it 'receives the signal' do
      @neutron_service_script.run

      expect(@tmpdir.contents_of 'signals').to eq <<-EXPECTED.gsub /^\s+/, ""
      term
      EXPECTED
    end
  end

end
