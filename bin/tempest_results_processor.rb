#!/usr/bin/ruby

# Copyright 2013, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Generate CSV for importing tempest results into Excel/OpenOffice. 
# The main usecase is to compare two sets of test results to see the delta but 
# it will accept a single filename as input as well if you just want a simple CSV of saved xml output.

require 'rubygems'
require 'xmlsimple'

class TempestResultsProcessor
  
 DOES_NOT_EXIST = 0
 ERROR = 1
 FAILED = 2
 SKIPPED = 3
 
 def  run(args, options={"ForceArray" => false})
    no_compare = true if args.size==1
    currXml = args[0]
    prevXml = args[1] unless no_compare
    currHash = XmlSimple.xml_in(currXml, options)
    prevHash = XmlSimple.xml_in(prevXml, options) unless no_compare
    puts "File Name,Tests,Errors,Failures,Skipped"
    puts "#{currXml},#{currHash['tests']},#{currHash['errors']},#{currHash['failures']},#{currHash['skip']}"
    puts "#{prevXml},#{prevHash['tests']},#{prevHash['errors']},#{prevHash['failures']},#{prevHash['skip']}" unless no_compare
    puts 
    currcases =   currHash["testcase"]
    prevcases =   prevHash["testcase"]  unless no_compare
    classnames =  currcases.uniq { |tc| tc["classname"] }.map { |tcc| tcc["classname"] }
    header = "Test Class,Test Name,#{currXml}"
    header += ",#{prevXml},Delta?" unless no_compare
    puts header
    classnames.each do |cn|
      print "#{cn}"
      currcases.select {|tc| tc["classname"]==cn}.each do |cnn|
        result = ",#{cnn['name']},"
        res1 = nil
        res2 = nil
        if !cnn["skipped"].nil?
          result += "skipped"
          res1 = SKIPPED
        elsif !cnn["error"].nil?
          result += "error"
          res1 = ERROR
        elsif !cnn["failure"].nil?
          result += "failed"
          res1 = FAILED
        else
          result += "#{cnn["time"]}"
        end
        
        unless no_compare
          # find previous result
          prevcase = prevcases.select {|ptc| ptc["classname"]==cn && ptc["name"]==cnn["name"]}.first
          if prevcase.nil?
            result += ",NA"
            res2 = DOES_NOT_EXIST
          elsif !prevcase["skipped"].nil?
            result += ",skipped"
            res2 = SKIPPED
          elsif !prevcase["error"].nil?
            result += ",error"
            res2 = ERROR
          elsif !prevcase["failure"].nil?
            result += ",failed"
            res2 = FAILED
          else
            result += ",#{prevcase["time"]}"
          end 
        end
        if !no_compare && res1 != res2
          result += ",*"
        end
        puts result
      end
    end
  end
end

if __FILE__ == $0
  if ARGV.empty?
    puts "Usage: tempest_results_processor.rb new_results.xml [prev_results.xml]"
    exit
  end
  processor = TempestResultsProcessor.new
  processor.run ARGV

end






