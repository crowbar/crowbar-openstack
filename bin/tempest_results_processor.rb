#!/usr/bin/ruby
#
# Copyright 2011-2013, Dell
# Copyright 2013-2014, SUSE LINUX Products GmbH
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

# Generate Excel spreadsheet comparing two tempest result sets or simply format a single result set
# The main usecase is to compare two sets of test results to see the delta but 
# it will accept a single filename as input as well if you just want a simple spreadsheet from saved xml output. 

require 'rubygems'
require 'xmlsimple'
require 'axlsx'

class TempestResultsProcessor
  
 DOES_NOT_EXIST = 0
 ERROR = 1
 FAILED = 2
 SKIPPED = 3
 DELTA_BG = "FFD0D0"
 HEADER_BG = "004586"
 HEADER_FG = "FFFFFF"
 
 def  run(args, options={"ForceArray" => false})
     p = Axlsx::Package.new

     styles = p.workbook.styles 
     delta_style = styles.add_style :bg_color => DELTA_BG,
                            :alignment => { :horizontal => :left,
                                            :vertical => :top ,
                                            :wrap_text => true}
                            
     header_style = styles.add_style :fg_color=> HEADER_FG,
                            :b => true,
                            :bg_color => HEADER_BG,
                            :sz => 12,
                            :border => { :style => :thin, :color => "00" },
                            :alignment => { :horizontal => :left,
                                            :vertical => :top ,
                                            :wrap_text => false}
    normal_style = styles.add_style :alignment => { :horizontal => :left,
                                            :vertical => :top ,
                                            :wrap_text => true}

    no_compare = true if args.size==1
    currXml = args[0]
    prevXml = args[1] unless no_compare
    currHash = XmlSimple.xml_in(currXml, options)
    prevHash = XmlSimple.xml_in(prevXml, options) unless no_compare
    
    p.workbook.add_worksheet(:name => "Test Summary") do |sheet|
        sheet.add_row ["File Name","Tests","Errors","Failures","Skipped"], :style=>header_style
        sheet.add_row [currXml, currHash['tests'], currHash['errors'],currHash['failures'],currHash['skip']], :style=>normal_style
        sheet.add_row [prevXml, prevHash['tests'], prevHash['errors'],prevHash['failures'],prevHash['skip']], :style=>normal_style unless no_compare  
    end

    p.workbook.add_worksheet(:name => "Test Results") do |sheet|
      row = sheet.add_row ["Test Class","Test Name",currXml]
      row.add_cell prevXml unless no_compare
      row.style=header_style
      currcases =   currHash["testcase"]
      prevcases =   prevHash["testcase"]  unless no_compare
      classnames =  currcases.uniq { |tc| tc["classname"] }.map { |tcc| tcc["classname"] }
      classnames.each do |cn|
        currcases.select {|tc| tc["classname"]==cn}.each do |cnn|
          row = sheet.add_row [cn]
          row.add_cell cnn['name']
          res1 = nil
          res2 = nil
          if !cnn["skipped"].nil?
            row.add_cell "skipped"
            res1 = SKIPPED
          elsif !cnn["error"].nil?
            row.add_cell "error"
            res1 = ERROR
          elsif !cnn["failure"].nil?
            row.add_cell "failed"
            res1 = FAILED
          else
            row.add_cell cnn["time"]
          end

          unless no_compare
            # find previous result
            prevcase = prevcases.select {|ptc| ptc["classname"]==cn && ptc["name"]==cnn["name"]}.first
            if prevcase.nil?
              row.add_cell "NA"
              res2 = DOES_NOT_EXIST
            elsif !prevcase["skipped"].nil?
              row.add_cell "skipped"
              res2 = SKIPPED
            elsif !prevcase["error"].nil?
              row.add_cell "error"
              res2 = ERROR
            elsif !prevcase["failure"].nil?
              row.add_cell "failed"
              res2 = FAILED
            else
              row.add_cell prevcase["time"]
            end
          end
          row.style=normal_style
          if !no_compare && res1 != res2
            row.add_cell "*"
            row.style=delta_style
          end
        end
      end
    end
    tm = Time.new
    time_stamp = "#{tm.year}#{tm.month}#{tm.day}#{tm.hour}#{tm.min}#{tm.sec}"
    filename = "tempest_results_#{time_stamp}.xlsx"
    p.use_shared_strings = true
    
    p.serialize(filename)
 
    puts  "Output generated, file name: #{filename}" 
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