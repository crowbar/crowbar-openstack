#
# Copyright 2011-2013, Dell
# Copyright 2013-2015, SUSE Linux GmbH
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

begin
  require "sprockets/standalone"

  Sprockets::Standalone::RakeTask.new(:assets) do |task, sprockets|
    task.assets = [
      "**/application.js"
    ]

    task.sources = [
      "crowbar_framework/app/assets/javascripts"
    ]

    task.output = "crowbar_framework/public/assets"

    task.compress = true
    task.digest = true

    sprockets.js_compressor = :uglifier
    sprockets.css_compressor = :sass
  end

  namespace :assets do
    def available_assets
      Pathname.glob(
        File.expand_path(
          "../crowbar_framework/public/assets/**/*",
          __FILE__
        )
      )
    end

    def digested_regex
      /(-{1}[a-z0-9]{32}*\.{1}){1}/
    end

    task :setup_logger do
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::INFO
    end

    task non_digested: :setup_logger do
      available_assets.each do |asset|
        next if asset.directory?
        next unless asset.to_s =~ digested_regex

        simple = asset.dirname.join(
          asset.basename.to_s.gsub(digested_regex, ".")
        )

        if simple.exist?
          simple.delete
        end

        @logger.info "Symlinking #{simple}"
        simple.make_symlink(asset.basename)
      end
    end

    task clean_dangling: :setup_logger do
      available_assets.each do |asset|
        next if asset.directory?
        next if asset.to_s =~ digested_regex

        next unless asset.symlink?

        # exist? is enough for checking the symlink target as it resolves the
        # link target and checks if that really exists. The check for having a
        # symlink is already done above.
        unless asset.exist?
          @logger.info "Removing #{asset}"
          asset.delete
        end
      end
    end
  end

  Rake::Task["assets:compile"].enhance do
    Rake::Task["assets:non_digested"].invoke
    Rake::Task["assets:clean_dangling"].invoke
  end
rescue
end

unless ENV["PACKAGING"] && ENV["PACKAGING"] == "yes"
  require "rspec/core/rake_task"
  require "foodcritic"
  RSpec::Core::RakeTask.new(:spec)

  task :syntaxcheck do
    system("for f in `find -not -path './vendor*' -name \*.rb`; do echo -n \"Syntaxcheck $f: \"; ruby -wc $f || exit $? ; done")
    exit $?.exitstatus
  end

  desc "Runs foodcritic against all the cookbooks."
  task :foodcritic do
    # we use -t ~VALUE to remove rules that are useless to us
    # FC037 -> Invalid notification action. This rule does not seem to work if you
    # use a var as the action as we do to create/delete resources in some cookbooks
    # FC001 -> Use strings in preference to symbols to access node attributes
    # totally a rule that depends on choice, should not be enforced unless we agree to use
    # a standard choice for attributes across all cookbooks, so disable it for the moment
    # Also disable all chef>10 as doesnt affect us and the metadata rules as we ignore
    # updating the metadata.rb files everywhere
    FoodCritic::Rake::LintTask.new do |t|
      t.options = {
        cookbook_paths: "chef/cookbooks",
        epic_fail: true,
        progress: true,
        tags: %w(~FC001 ~FC037 ~chef11 ~chef12 ~chef13 ~metadata )
      }
    end
  end

  task default: [
    :spec,
    :syntaxcheck
  ]
end
