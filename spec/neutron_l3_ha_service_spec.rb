#
# Copyright 2017, SUSE Linux GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'tmpdir'
require 'rbconfig'
require_relative '../chef/cookbooks/neutron/files/default/neutron-l3-ha-service'


$RUBY = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])
$SMALL_DELAY = 1  # seconds to wait for simple subprocesses to complete. It might depend on the speed of your computer


class Tmpdir
  # Helper class for creating files and getting their contents
  # within a temporary directory.
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


def with_tmpdir
  Dir.mktmpdir do |tmpdir|
    yield Tmpdir.new(tmpdir)
  end
end


describe ServiceOptions do
  context 'valid settings file' do
    around do |example|
      with_tmpdir do |tmpdir|
        @tmpdir = tmpdir
        tmpdir.write_file 'settings.yml', {
          'timeouts' => {
            'status' => {
              'terminate' => 1,
              'kill' => 2
            },
            'dhcp_replication' => {
              'terminate' => 3,
              'kill' => 4
            },
            'router_migration' => {
              'terminate' => 5,
              'kill' => 6
            }
          },
          'hatool' => {
            'program' => 'path-to-hatool',
            'env' => {
              'some-key' => 'some-value'
            },
            'insecure' => 'false'
          },
          'seconds_to_sleep_between_checks' => '10',
          'max_errors_tolerated' => '13',
        }.to_yaml
        example.run
      end
    end

    it 'loads status timeout' do
      service_options = ServiceOptions.load(@tmpdir.path_for('settings.yml'))
      expect(service_options.status_timeout.terminate).to eq 1
      expect(service_options.status_timeout.kill).to eq 2
    end

    it 'loads dhcp replication timeout' do
      service_options = ServiceOptions.load(@tmpdir.path_for('settings.yml'))
      expect(service_options.dhcp_replication_timeout.terminate).to eq 3
      expect(service_options.dhcp_replication_timeout.kill).to eq 4
    end

    it 'loads router migration timeouts' do
      service_options = ServiceOptions.load(@tmpdir.path_for('settings.yml'))
      expect(service_options.router_migration_timeout.terminate).to eq 5
      expect(service_options.router_migration_timeout.kill).to eq 6
    end

    it 'loads hatool parameters' do
      service_options = ServiceOptions.load(@tmpdir.path_for('settings.yml'))
      expect(service_options.hatool.program).to eq 'path-to-hatool'
      expect(service_options.hatool.env).to eq({'some-key' => 'some-value'})
    end

    it 'loads seconds_to_sleep_between_checks parameter' do
      service_options = ServiceOptions.load(@tmpdir.path_for('settings.yml'))
      expect(service_options.seconds_to_sleep_between_checks).to eq 10
    end

    it 'loads max_errors_tolerated parameter' do
      service_options = ServiceOptions.load(@tmpdir.path_for('settings.yml'))
      expect(service_options.max_errors_tolerated).to eq 13
    end

    it 'loads insecure parameter' do
      service_options = ServiceOptions.load(@tmpdir.path_for('settings.yml'))
      expect(service_options.hatool.insecure).to eq false
    end
  end
end


describe TimeoutOptions do
  context 'mixed strings and numbers' do
    before do
      @data = {
        'terminate' => 1,
        'kill' => '2'
      }
    end

    it 'converts them to integers' do
      timeout_options = TimeoutOptions.from_hash(@data)

      expect(timeout_options.terminate).to eq 1
      expect(timeout_options.kill).to eq 2
    end
  end
end


def sleep_workaround_for_subprocess
  # After starting the subprocess, a small delay has to be added, otherwise
  # the signals will not be received by the created processes for some reason
  sleep 0.2
end


describe Subprocess do
  it 'exit_status set to the exit code of the subprocess' do
    subprocess = Subprocess.new $RUBY, '-e', 'exit 1'

    subprocess.start
    result = subprocess.wait 1

    expect(result.exit_status).to eq 1
  end

  it 'wait raises exception when run times out' do
    subprocess = Subprocess.new $RUBY, '-e', 'sleep 0.2'

    subprocess.start

    expect { subprocess.wait 0.1 }.to raise_error TimedOut
  end

  it 'output contains stdout of subprocess' do
    subprocess = Subprocess.new $RUBY, '-e', 'puts "hello"'

    subprocess.start
    run_result = subprocess.wait $SMALL_DELAY

    expect(run_result.output).to include 'hello'
  end

  it 'error contains stderr of subprocess' do
    subprocess = Subprocess.new $RUBY, '-e', 'STDERR.puts "hello"'

    subprocess.start
    run_result = subprocess.wait $SMALL_DELAY

    expect(run_result.error).to include 'hello'
  end

  it 'raises error when executable not found' do
    subprocess = Subprocess.new 'nonexisting-executable'

    expect { subprocess.start }.to raise_error
  end

  it 'raises an error when user waits for an already terminated subprocess' do
    subprocess = Subprocess.new $RUBY, '-e', ''

    subprocess.start
    subprocess.wait 1

    expect { subprocess.wait 1 }.to raise_error
  end

  context 'running a subprocess that exits with 2 on term signal' do
    around do |example|
      with_tmpdir do |tmpdir|
        tmpdir.write_script 'somescript', <<-EOF
        Signal.trap 'TERM' do
          exit 2
        end
        sleep 2
        exit 1
        EOF
        @path_to_script = tmpdir.path_for 'somescript'
        example.run
      end
    end

    it 'gets 2 as an exit value when term sent to subprocess' do
      subprocess = Subprocess.new $RUBY, @path_to_script
      subprocess.start

      sleep_workaround_for_subprocess
      subprocess.send_signal 'TERM'
      run_result = subprocess.wait 1

      expect(run_result.exit_status).to eq 2
    end
  end

  it 'converts environment values to strings' do
    subprocess = Subprocess.new 'irrelevant'
    subprocess.env['somekey'] = 3

    expect(subprocess.environment).to eq({'somekey' => '3'})
  end

  context 'running a subprocess that exits with the value of EXITVAL environment variable' do
    around do |example|
      with_tmpdir do |tmpdir|
        tmpdir.write_script 'somescript', <<-EOF
        exit ENV["EXITVAL"].to_i
        EOF
        @path_to_script = tmpdir.path_for 'somescript'
        example.run
      end
    end

    it 'gets exit code 2 when EXITVAL=2' do
      subprocess = Subprocess.new $RUBY, @path_to_script
      subprocess.env['EXITVAL'] = 43
      subprocess.start

      run_result = subprocess.wait 1

      expect(run_result.exit_status).to eq 43
    end
  end

  context 'running a subprocess that takes a long time' do
    around do |example|
      with_tmpdir do |tmpdir|
        tmpdir.write_script 'somescript', <<-EOF
        STDOUT.puts 'text on stdout'
        STDERR.puts 'text on stderr'
        STDOUT.flush
        STDERR.flush
        sleep 1000
        EOF
        @path_to_script = tmpdir.path_for 'somescript'
        example.run
      end
    end

    it 'returns with nil exit status when process is killed' do
      subprocess = Subprocess.new $RUBY, @path_to_script
      subprocess.start

      sleep_workaround_for_subprocess
      subprocess.send_signal 'KILL'

      run_result = subprocess.wait 1

      expect(run_result.exit_status).to eq nil
    end

    it 'returns the ooutput of the process killed' do
      subprocess = Subprocess.new $RUBY, @path_to_script
      subprocess.start

      sleep_workaround_for_subprocess
      subprocess.send_signal 'KILL'

      run_result = subprocess.wait 1

      expect(run_result.output).to include 'text on stdout'
      expect(run_result.error).to include 'text on stderr'
    end
  end

  context 'running a subprocess that quits promptly' do
    around do |example|
      with_tmpdir do |tmpdir|
        tmpdir.write_script 'somescript', <<-EOF
        puts 'hi'
        EOF
        @path_to_script = tmpdir.path_for 'somescript'
        example.run
      end
    end

    specify "should ignore when signal sent to a finished process" do
      subprocess = Subprocess.new $RUBY, @path_to_script
      subprocess.start

      sleep 0.4 #  Assuming that this is enough time for the process to die

      subprocess.send_signal 'TERM'
    end
  end
end

describe HATool do
  context 'insecure flag is false' do
    before do
      @ha_tool = HATool.new(HAToolOptions.new('hatool', {}, false))
    end

    describe '#get_help' do
      it 'calls subprocess with timeout' do
        subprocess = double
        env = double
        allow(Subprocess).to receive(:new) { subprocess }
        allow(subprocess).to receive(:start)
        allow(subprocess).to receive(:env) {env}
        allow(env).to receive(:merge!)
        expect(subprocess).to receive(:wait).with(1) { RunResult.new 'out', 'err', 0 }

        @ha_tool.get_help
      end

      it 'returns the standard output of the subprocess' do
        subprocess = double
        env = double
        allow(Subprocess).to receive(:new) { subprocess }
        allow(subprocess).to receive(:start)
        allow(subprocess).to receive(:env) {env}
        allow(env).to receive(:merge!)
        allow(subprocess).to receive(:wait).with(1) { RunResult.new 'out', 'err', 0 }

        result = @ha_tool.get_help
        expect(result).to eq 'out'
      end

      it 'raises an error if result is non-zero' do
        subprocess = double
        allow(Subprocess).to receive(:new) { subprocess }
        allow(subprocess).to receive(:wait).with(1) { RunResult.new 'out', 'err', 1 }

        expect { @ha_tool.get_help }.to raise_error
      end
    end
  end

  context 'insecure flag is false' do
    before do
      @options = HAToolOptions.new('hatool', {}, false)
    end

    it 'queries hatool with --help' do
      hatool = HATool.new @options
      allow(hatool).to receive(:get_help) { 'something' }
      expect(hatool).to receive(:get_help)

      hatool.discover_capabilities
    end

    context 'hatool --help output does not contain --retry' do
      before do
        @hatool = HATool.new @options
        allow(@hatool).to receive(:get_help) { 'something' }
      end

      it 'does not set retry flag' do
        @hatool.discover_capabilities

        expect(@hatool.extra_flags).to eq []
      end
    end

    context 'hatool --help output contains --retry' do
      before do
        @hatool = HATool.new @options
        allow(@hatool).to receive(:get_help) { '--retry' }
      end

      it 'sets retry flag' do
        @hatool.discover_capabilities

        expect(@hatool.extra_flags).to eq ['--retry']
      end
    end

    it 'excludes extra_flags for status check' do
      hatool = HATool.new @options
      hatool.extra_flags.push 'extra'

      expected = ['hatool', '--l3-agent-check', '--quiet']
      expect(hatool.status_command).to eq expected
    end

    it 'includes extra_flags for dhcp replication' do
      hatool = HATool.new @options
      hatool.extra_flags.push 'extra'

      expected = ['hatool', '--replicate-dhcp', 'extra']
      expect(hatool.replicate_dhcp_command).to eq expected
    end

    it 'includes extra_flags for agent migration' do
      hatool = HATool.new @options
      hatool.extra_flags.push 'extra'

      expected = ['hatool', '--l3-agent-migrate', '--now', 'extra']
      expect(hatool.migration_command).to eq expected
    end
  end

  context 'insecure flag is true' do
    before do
      @options = HAToolOptions.new('hatool', {}, true)
    end

    it 'includes --insecure for dhcp replication' do
      hatool = HATool.new @options

      expect(hatool.replicate_dhcp_command).to include '--insecure'
    end

    it 'includes --insecure for agent migration' do
      hatool = HATool.new @options

      expect(hatool.migration_command).to include '--insecure'
    end


  end
end


describe Supervisor do
  context 'subprocess does not time out' do
    before do
      timeout_options = TimeoutOptions.new 10, 2
      @subprocess = double
      allow(@subprocess).to receive(:start)
      allow(@subprocess).to receive(:wait) { RunResult.new 'out', 'err', 1 }
      @supervisor = Supervisor.new @subprocess, timeout_options
    end

    it 'runs subprocess and waits' do
      expect(@subprocess).to receive(:start).with(no_args)
      expect(@subprocess).to receive(:wait).with(10)

      @supervisor.run_subprocess
    end

    it 'returns with the results of the subprocess' do
      result = @supervisor.run_subprocess

      expect(result.output).to eq 'out'
      expect(result.error).to eq 'err'
      expect(result.exit_status).to eq 1
    end
  end

  context 'subprocess times out but responds to term signal' do
    before do
      timeout_options = TimeoutOptions.new 10, 2
      @subprocess = double
      allow(@subprocess).to receive(:start)
      @call_count = 0
      allow(@subprocess).to receive(:wait) do
        if @call_count == 0
          @call_count+=1
          raise TimedOut
        end
        RunResult.new 'out', 'err', 1
      end
      allow(@subprocess).to receive(:send_signal)
      @supervisor = Supervisor.new @subprocess, timeout_options
    end

    it 'sends the subprocess term signal' do
      expect(@subprocess).to receive(:start).with(no_args)
      expect(@subprocess).to receive(:wait).with(10)
      expect(@subprocess).to receive(:send_signal).with('TERM')
      expect(@subprocess).to receive(:wait).with(2)

      @supervisor.run_subprocess
    end

    it 'returns with the results of the subprocess' do
      result = @supervisor.run_subprocess

      expect(result.output).to eq 'out'
      expect(result.error).to eq 'err'
      expect(result.exit_status).to eq 1
    end

  end

  context 'subprocess does not respond to term' do
    before do
      timeout_options = TimeoutOptions.new 10, 2
      @subprocess = double
      allow(@subprocess).to receive(:start)
      @call_count = 0
      allow(@subprocess).to receive(:wait) do
        if @call_count < 2
          @call_count+=1
          raise TimedOut
        end
        RunResult.new 'out', 'err', nil
      end
      allow(@subprocess).to receive(:send_signal)
      @supervisor = Supervisor.new @subprocess, timeout_options
    end

    it 'sends the subprocess term and kill signal' do
      expect(@subprocess).to receive(:start).with(no_args)
      expect(@subprocess).to receive(:wait).with(10)
      expect(@subprocess).to receive(:send_signal).with('TERM')
      expect(@subprocess).to receive(:wait).with(2)
      expect(@subprocess).to receive(:send_signal).with('KILL')
      expect(@subprocess).to receive(:wait).with(1)

      @supervisor.run_subprocess
    end

    it 'returns with the results of the subprocess' do
      result = @supervisor.run_subprocess

      expect(result.output).to eq 'out'
      expect(result.error).to eq 'err'
      expect(result.exit_status).to eq nil
    end
  end
end


describe ErrorCounter do
  it 'registers number of errors' do
    error_counter = ErrorCounter.new 1
    error_counter.bump!

    expect(error_counter.errors).to eq 1
  end

  it 'resets the number of errors' do
    error_counter = ErrorCounter.new 1
    error_counter.bump!
    error_counter.reset!

    expect(error_counter.errors).to eq 0
  end

  it 'raises an error if error count is above tolerated' do
    error_counter = ErrorCounter.new 1
    error_counter.bump!
    expect { error_counter.bump! }.to raise_error MaximumErrorsReached
  end
end


def make_config tmpdir
  tmpdir.write_file 'settings.yml', {
    'timeouts' => {
      'status' => {
        'terminate' => 1,
        'kill' => 2
      },
      'dhcp_replication' => {
        'terminate' => 3,
        'kill' => 4
      },
      'router_migration' => {
        'terminate' => 5,
        'kill' => 6
      }
    },
    'hatool' => {
      'program' => @hatool_path,
      'env' => {},
      'insecure' => 'false'
    },
    'seconds_to_sleep_between_checks' => '10',
    'max_errors_tolerated' => '10',
  }.to_yaml
end


describe 'neutron-l3-ha-service' do
  context 'hatool reports dead agents' do
    around do |example|
      with_tmpdir do |tmpdir|
        @hatool_path = tmpdir.write_script 'fake-hatool', <<-EOF.gsub(/^\s+/, '')
        #!#{$RUBY}
        puts (["HATOOL-CALL"] + ARGV).join(' ')
        if ARGV.include? '--help'
          puts '--retry'
          exit 0
        end
        exit 2 if ARGV.include? '--l3-agent-check'
        EOF

        @settings_path = make_config tmpdir
        @tmpdir = tmpdir
        @ruby = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])
        @service_path = 'chef/cookbooks/neutron/files/default/neutron-l3-ha-service.rb'
        example.run
      end
    end

    it 'performs migration' do
      subprocess = Subprocess.new @ruby, @service_path, @settings_path
      subprocess.start
      sleep_workaround_for_subprocess
      sleep 1  # Let it run for a while
      subprocess.send_signal 'TERM'
      result = subprocess.wait 0.1

      expect(result.error).to include 'HATOOL-CALL --help'
      expect(result.error).to include 'HATOOL-CALL --l3-agent-check --quiet'
      expect(result.error).to include 'HATOOL-CALL --replicate-dhcp --retry'
      expect(result.error).to include 'HATOOL-CALL --l3-agent-migrate --now --retry'

      expect(result.exit_status).to eq 0
    end
  end

  context 'hatool reports dead agents, migration takes a lot of time' do
    around do |example|
      with_tmpdir do |tmpdir|
        @hatool_path = tmpdir.write_script 'fake-hatool', <<-EOF.gsub(/^\s+/, '')
        #!#{$RUBY}
        Signal.trap 'TERM' do
          puts 'HATOOL RECEIVED TERM SIGNAL'
          exit 0
        end

        puts (["HATOOL-CALL"] + ARGV).join(' ')

        exit 2 if ARGV.include? '--l3-agent-check'
        if ARGV.include? '--l3-agent-migrate'
          puts 'MIGRATING AGENTS'
          sleep 1000
        end
        EOF

        @settings_path = make_config tmpdir
        @tmpdir = tmpdir
        @ruby = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])
        @service_path = 'chef/cookbooks/neutron/files/default/neutron-l3-ha-service.rb'
        example.run
      end
    end

    it 'TERM signal sent to the process group reaches hatool' do
      # This test emulates what happens, when the TERM signal is sent to the process group of the
      # service process. What we are expecting is that both the child process (hatool) and the service
      # script receives the signal. Service script waits for the child process to respond, and only terminates
      # afterwards.

      # Start a subprocess in a new process group (as systemd would do)
      stdin, stdout, stderr, wait_thr = Open3.popen3(@ruby, @service_path, @settings_path, :pgroup => true)
      stdin.close()
      sleep 1  # Let the script run for a while, so we know it's now sleeping inside l3-agent-migration

      Process.kill('TERM', -Process.getpgid(wait_thr.pid))

      exit_status = wait_thr.value
      output = stdout.read()
      error = stderr.read()

      expect(error).to include 'HATOOL-CALL --help'
      expect(error).to include 'HATOOL-CALL --l3-agent-check --quiet'
      expect(error).to include 'HATOOL-CALL --replicate-dhcp'
      expect(error).to include 'HATOOL-CALL --l3-agent-migrate --now'
      expect(error).to include 'HATOOL RECEIVED TERM SIGNAL'

      expect(exit_status).to eq 0
    end
  end
end
