#!/usr/bin/env ruby
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

require 'yaml'
require 'open3'
require 'logger'

class HAToolLog
  def self.log
    if @logger.nil?
      @logger = Logger.new(STDERR)
      @logger.level = Logger::DEBUG
    end
    @logger
  end

  def self.file=(file_path)
    @logger = Logger.new(file_path, "daily") unless file_path.nil?
  end
end

def main
  terminator = Terminator.new
  terminator.register_term_signal_handler
  service_options = ServiceOptions.load ARGV[0]
  ha_functions = HAFunctions.new(service_options)
  error_counter = ErrorCounter.new service_options.max_errors_tolerated
  HAToolLog.file = service_options.log_file

  while true
    status = ha_functions.check_l3_agents
    if status.exit_status == 2
      error_counter.reset!

      register_errors_to(
        error_counter,
        terminator.dont_exit_until_block_finished do
          ha_functions.migrate_routers_away_from_dead_agents
        end
      )
    elsif status.exit_status == 0
      error_counter.reset!
    else
      error_counter.bump!
    end

    HAToolLog.log.info("Sleeping until next run")
    sleep service_options.seconds_to_sleep_between_checks
  end
end


def register_errors_to error_counter, result
  if result.exit_status == 0
    error_counter.reset!
  else
    error_counter.bump!
  end
end


class Terminator
  def initialize
    @immediate_exit_enabled = true
    @exit_requested = false
  end

  def register_term_signal_handler
    Signal.trap "TERM" do
      exit 0 if @immediate_exit_enabled
      @exit_requested = true
    end
  end

  def dont_exit_until_block_finished
    @immediate_exit_enabled = false
    result = yield
    @immediate_exit_enabled = true
    if @exit_requested
      HAToolLog.log.info("TERM signal received while waiting for block to finish, exiting now")
      exit 0
    end
    result
  end
end


class HAFunctions
  def initialize(service_options)
    @service_options = service_options
    @hatool = HATool.new service_options.hatool
    # TODO(mlakat): Check if we can skip this step
    # maybe we should just assume that the tool supports --retry?
  end

  def check_l3_agents
    HAToolLog.log.info("checking for dead agents")
    run_supervised(
      @hatool.status_command,
      @service_options.status_timeout
    )
  end

  def migrate_routers_away_from_dead_agents
    HAToolLog.log.info("migrating routers away from dead agents")
    run_supervised(
      @hatool.migration_command,
      @service_options.router_migration_timeout
    )
  end

  def run_supervised(command, timeout)
    subprocess = Subprocess.new *command
    subprocess.env.merge! @service_options.hatool.env
    supervisor = Supervisor.new(subprocess, timeout)
    supervisor.run_subprocess
  end
end


class TimedOut < StandardError
end


class MaximumErrorsReached < StandardError
end


class AlreadyCompleted < StandardError
end


class RunningHelpFailed < StandardError
end


class LoggingStreamReader
  def initialize
    @lines = []
    @thread = nil
  end

  def read stream, log_msg
    @thread = Thread.new do
      stream.each do |line|
        @lines << line
        HAToolLog.log.info("#{log_msg} #{line}")
      end
    end
  end

  def content
    @lines.join("\n")
  end

  def join
    # Leave 1 second for the thread to join, otherwise raise an exception
    result = @thread.join 1
    if result.nil?
      raise StandardError
    end
  end
end


class Subprocess
  attr_reader :env

  def initialize *args
    @args = args
    @completed = false
    @env = {}
    @stdout_reader = LoggingStreamReader.new
    @stderr_reader = LoggingStreamReader.new
  end

  def environment
    Hash[@env.map { |key, val| [key, val.to_s] }]
  end

  def start
    stdin, stdout, stderr, @wait_thr = Open3.popen3(environment, *@args)
    @pid = @wait_thr.pid
    @stdout_reader.read stdout, "#{self} stdout:"
    @stderr_reader.read stderr, "#{self} stderr:"
    stdin.close
  end

  def wait timeout
    if @completed
      raise AlreadyCompleted
    end
    wait_result = @wait_thr.join(timeout)
    if wait_result.nil?
      raise TimedOut
    else
      @completed = true
      @stdout_reader.join
      @stderr_reader.join
      output = @stdout_reader.content
      error = @stderr_reader.content
      exitstatus = @wait_thr.value.exitstatus
      RunResult.new output, error, exitstatus
    end
  end

  def send_signal signal
    begin
      Process.kill(signal, @pid)
    rescue Errno::ESRCH
      # Process already killed
    end
  end

  def to_s
    status = @pid.nil? ? "not-started-yet" : @pid.to_s
    status = "already-exited" if @completed
    "Subprocess(#{@args.join " "})[#{status}]"
  end
end


class ServiceOptions
  attr_reader :status_timeout
  attr_reader :router_migration_timeout
  attr_reader :hatool
  attr_reader :seconds_to_sleep_between_checks
  attr_reader :max_errors_tolerated
  attr_reader :log_file

  def initialize(params = {})
    @status_timeout = params.fetch(:status_timeout)
    @router_migration_timeout = params.fetch(:router_migration_timeout)
    @hatool = params.fetch(:hatool_options)
    @seconds_to_sleep_between_checks = params.fetch(:sleep_time)
    @max_errors_tolerated = params.fetch(:max_errors_tolerated)
    @log_file = params.fetch(:log_file)
  end

  def self.load(path)
    File.open path do |file|
      data = YAML.load file.read
      ServiceOptions.new(
        status_timeout: TimeoutOptions.from_hash(data["timeouts"]["status"]),
        router_migration_timeout: TimeoutOptions.from_hash(data["timeouts"]["router_migration"]),
        hatool_options: HAToolOptions.from_hash(data["hatool"]),
        sleep_time: data["seconds_to_sleep_between_checks"].to_i,
        max_errors_tolerated: data["max_errors_tolerated"].to_i,
        log_file: data["log_file"]
      )
    end
  end
end


class ErrorCounter
  attr_reader :errors

  def initialize max_errors_tolerated
    @max_errors_tolerated = max_errors_tolerated
    @errors = 0
  end

  def reset!
    HAToolLog.log.info("error counter: re-set to 0")
    @errors = 0
  end

  def bump!
    @errors += 1
    HAToolLog.log.info("error counter: bumped to #{@errors}")
    if @errors > @max_errors_tolerated
      HAToolLog.log.error("error counter: exceeded limit #{@max_errors_tolerated}")
      raise MaximumErrorsReached
    end
  end
end


class Supervisor
  def initialize subprocess, timeout_options
    @subprocess = subprocess
    @timeout_options = timeout_options
  end

  def run_subprocess
    HAToolLog.log.info("supervisor: starting #{@subprocess}")
    @subprocess.start
    HAToolLog.log.info("supervisor: monitoring #{@subprocess}")

    result = begin
      @subprocess.wait @timeout_options.terminate
    rescue TimedOut
      HAToolLog.log.info("supervisor: #{@subprocess} did not terminate, sending TERM signal")
      @subprocess.send_signal "TERM"
      begin
        @subprocess.wait @timeout_options.kill
      rescue TimedOut
        HAToolLog.log.info("supervisor: #{@subprocess} did not terminate, sending KILL signal")
        @subprocess.send_signal "KILL"
        @subprocess.wait 1
      end
    end

    HAToolLog.log.info("supervisor: done running #{@subprocess} exited with: #{result.exit_status}")
    result
  end
end

class HATool
  attr_reader :extra_flags

  def initialize(options)
    @extra_flags = ["--retry"]
    @options = options
  end

  def insecure_flag
    @options.insecure ? ["--insecure"] : []
  end

  def status_command
    [@options.program, "--l3-agent-check", "--quiet"] + insecure_flag
  end

  def migration_command
    [@options.program, "--l3-agent-migrate", "--now"] + @extra_flags + insecure_flag
  end
end

class RunResult
  attr_reader :output
  attr_reader :error
  attr_reader :exit_status

  def initialize(output, error, exit_status)
    @output = output
    @error = error
    @exit_status = exit_status
  end
end

class TimeoutOptions
  attr_reader :terminate
  attr_reader :kill

  def initialize(terminate_timeout, kill_timeout)
    @terminate = terminate_timeout.to_i
    @kill = kill_timeout.to_i
  end

  def self.from_hash(hash)
    TimeoutOptions.new hash["terminate"], hash["kill"]
  end
end

class HAToolOptions
  attr_reader :program
  attr_reader :env
  attr_reader :insecure

  def initialize(program, env, insecure)
    @program = program
    @env = env
    @insecure = insecure
  end

  def self.to_bool(value)
    value.to_s == "true"
  end

  def self.from_hash(hash)
    HAToolOptions.new hash["program"], hash["env"], to_bool(hash["insecure"])
  end
end

main if __FILE__ == $PROGRAM_NAME
