#
# OpenAttestation (v1.6) API client (https://github.com/OpenAttestation/OpenAttestation/tree/v1.6)
#
# Author: Shurmin Evgeniy
#
# Copyright 2013, Mirantis Inc.
#
# All rights reserved - Do Not Redistribute
#

require 'rubygems'
require 'net/http'
require 'net/https'
require 'uri'
#require 'json/pure'
require 'cgi'

# module OAT API Client
module OATClient
  class Exception < RuntimeError ; end
  # configuring OATClient
  # @param url [string] URL to server
  # @param secret [string] provide a password if required
  # @param options [Hash] addition options { :retries => 5, :wait => 3 }
  def self.config url, secret = nil, options = {}
    @url = url
    @options = options
    @options[:retries] ||= 5
    @options[:wait] ||= 3
    @headers = { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
    @headers['Auth_blob'] = secret if secret
  end

  # request API
  # @param type [:get, :post, :delete, :put] type of HTTP request
  # @param options [Hash] options for requests
  #   - :path - path for request
  #   - :query -  query for request
  #   - :params - params for request (only for :put, :post types)
  def self.request type, options = {}
    path = options[:path] || {}
    query = options[:query] || {}
    params = options[:params] || {}
    # delete key with nil values
    query.reject!{|_,value| value.nil? }

    # delete key with nil values
    params.reject!{|_,value| value.nil? }

    #puts "\n> #{type.to_s.upcase}: #{path}"
    #puts "> Query: #{query.inspect}"
    #puts "> Params: #{params.inspect}"
    #
    # prepare query with escape values
    query = (query || {}).collect{|key,value|"#{key.to_s}=#{CGI.escape(value)}"}.join("&")

    @options[:retries].times do |try|
      begin
        case type
          when :get,:delete then
            response = connection.send(type,[path,query].join("?"),@headers)
          when :put,:post then
            response = connection.send(type, [path,query].join("?"), JSON.generate(params), @headers)
          else
            raise RuntimeError.new("unknown request type '#{type}'")
        end
        case response.code.to_i
          when 200,202 then
            if response.body == "True"
              return true
            elsif response.body == "False"
              return false
            elsif response.body == "null"
              return  []
            else
              begin
                response = JSON response.body
                response = response[response.keys.first]
                response = response.kind_of?(Hash) ? [response] : response
                return response
              rescue JSON::ParserError
                raise OATClient::Exception.new(response.body)
              end
            end
          else
            begin
              response = JSON.parse(response.body)
            rescue JSON::ParserError
              raise OATClient::Exception.new(response.body)
            end
            raise OATClient::Exception.new("[#{response["error_code"]}] #{response["error_message"]}")
        end
      rescue OATClient::Exception => exception
        if try+1 < @options[:retries]
          puts "Receive error from OAT server, try repeat request"
          sleep @options[:wait]
          next
        end
        raise exception.message
      end
    end
  end

  # create connection
  # @return [Net::HTTP] connection for processing requests in {OATClient.request}
  def self.connection
    return @connection if defined? @connection
    uri = URI.parse(@url)
    @connection = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == "https"
      @connection.use_ssl = true
      @connection.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    return @connection
  end

  # base class for other models
  class Base
    def initialize params = {}
      params.each_pair do |key,value|
        next if value == "null"
        send "#{key}=", (value == "null" ? nil : value)
      end
      @new_record = true
    end
    # mark current model as not a new
    def not_new_model!
      @new_record = false
    end
    # search in models by params
    # @return [Array] found models
    def self.search models, params = {}
      result = []
      models.each do |model|
        included = true
        params.each do |key, value|
          included &= model.send(key).to_s == value.to_s
        end
        result << model if included
      end
      result
    end
  end

  # class for work with models of operating systems
  class OS < Base
    attr_accessor :name, :version, :description
    # search models by params
    def self.search params = {}
      super all, params
    end
    # delete current model
    # @return [True,False]
    def delete
      OATClient::request(:delete, :path => "/WLMService/resources/os", :query => {
          :Name => name,
          :Version => version
      })
    end
    # save current model
    # @return [True,False]
    def save
      type = (@new_record == true) ? :post : :put
      OATClient::request(type, :path => "/WLMService/resources/os", :params => {
          :Name => name,
          :Version => version,
          :Description => description
      })
    end
    # retrieve all OS models from server
    # @return [Array<OATClient::OS>]
    def self.all
      models = OATClient::request(:get, :path => "/WLMService/resources/os")
      models.collect do |item|
        model = new(:name => item["Name"],:version => item["Version"],:description => item["Description"])
        model.not_new_model!
        model
      end
    end
    # exists current model on OAT server?
    # @return [True, False]
    def exists?
      self.class.search(:name => name).any?
    end
  end

  # class for work with models of OEMs
  class OEM < Base
    attr_accessor :name, :description
    # retrieve all OS models from server
    # @return [Array<OATClient::OEM>]
    def self.all
      models = OATClient::request :get, :path => "/WLMService/resources/oem"
      models.collect do |item|
        model = new(:name => item["Name"],:description => item["Description"])
        model.not_new_model!
        model
      end
    end
    # search models by params
    def self.search params = {}
      super all, params
    end
    # save current model
    # @return [True,False]
    def save
      type = (@new_record == true) ? :post : :put
      OATClient::request(type, :path => "/WLMService/resources/oem", :params => {
          :Name => name,
          :Description => description
      })
    end
    # delete current model
    # @return [True,False]
    def delete
      OATClient::request(:delete, :path => "/WLMService/resources/oem", :query => {
          :Name => name
      })
    end
    # exists current model on OAT server?
    # @return [True, False]
    def exists?
      self.class.search(:name => name).any?
    end
  end

  # class for work with models of hosts
  class Host < Base
    attr_accessor :host_name, :ip_address, :port, :bios_name, :bios_version, :bios_oem, :vmm_name, :vmm_version, :vmm_os_name, :vmm_os_version, :addon_sonnection_string, :description, :email, :location
    # exists current model on OAT server?
    # @return [True, False]
    def exists?
      self.class.search(
          :host_name => host_name,
          :ip_address => ip_address,
          :port => port,
          :bios_name => bios_name,
          :bios_version => bios_version,
          :bios_oem => bios_oem,
          :vmm_name => vmm_name,
          :vmm_version => vmm_version,
          :vmm_os_name => vmm_os_name,
          :vmm_os_version => vmm_os_version,
          :addon_sonnection_string => addon_sonnection_string,
          :email => email,
          :location => location).any?
    end

    # retrieve all OS models from server
    # @return [Array<OATClient::Host>]
    def self.all
      models = OATClient::request(:get, :path => "/AttestationService/resources/hosts", :query => {:searchCriteria => "?"})
      models.collect do |item|
        model = new(
            :host_name => item["HostName"],
            :ip_address => item["IPAddress"],
            :port => item["Port"],
            :bios_name => item["BIOS_Name"],
            :bios_oem => item["BIOS_Oem"],
            :bios_version => item["BIOS_Version"],
            :vmm_name => item["VMM_Name"],
            :vmm_version => item["VMM_Version"],
            :vmm_os_name => item["VMM_OSName"],
            :vmm_os_version => item["VMM_OSVersion"],
            :addon_sonnection_string => item["AddOn_Connection_String"],
            :description => item["Description"],
            :email => item["Email"],
            :location => item["Location"]
        )
        model.not_new_model!
        model
      end
    end
    # save current model
    # @return [True,False]
    def save
      type = (@new_record == true) ? :post : :put
      OATClient::request(type, :path =>  "/AttestationService/resources/hosts", :params => {
          :HostName => host_name,
          :IPAddress => ip_address,
          :Port => port,
          :BIOS_Name => bios_name,
          :BIOS_Oem => bios_oem,
          :BIOS_Version => bios_version,
          :VMM_Name => vmm_name,
          :VMM_Version => vmm_version,
          :VMM_OSName => vmm_os_name,
          :VMM_OSVersion => vmm_os_version,
          :AddOn_Connection_String => addon_sonnection_string,
          :Description => description,
          :Email => email,
          :Location => location
      })
    end
    # search models by params
    def self.search params = {}
      super all, params
    end
    # delete current model
    # @return [True,False]
    def delete
      OATClient::request(:delete, :path =>   "/AttestationService/resources/hosts", :query => {
          :hostName => host_name
      })
    end
  end

  # class for work with models of MLEs
  class MLE < Base
    attr_accessor :name, :version, :os_name, :os_version, :attestation_type, :mle_type, :description, :oem_name, :manifests
    # exists current model on OAT server?
    # @return [True, False]
    def exists?
      self.class.search(
          :name => name,
          :version => version,
          :os_name => os_name,
          :os_version => os_version,
          :attestation_type => attestation_type,
          :mle_type => mle_type,
          :oem_name => oem_name
      ).any?
    end


    # retrieve all OS models from server
    # @return [Array<OATClient::MLE>]
    def self.all
      models = OATClient::request(:get, :path => "/WLMService/resources/mles", :query => {:searchCriteria => ""})
      models.collect do |item|
        model = new(
            :name => item["Name"],
            :version => item["Version"],
            :os_name => item["OsName"],
            :os_version => item["OsVersion"],
            :attestation_type => item["Attestation_Type"],
            :mle_type => item["MLE_Type"],
            :description => item["Description"],
            :oem_name => item["OemName"]
        )
        if item["MLE_Manifests"]
          item["MLE_Manifests"] = [item["MLE_Manifests"]] if item["MLE_Manifests"].kind_of? Hash
          model.manifests = item["MLE_Manifests"].collect do |manifest|
            MLE::Manifest.new(
                :name => manifest["Name"],
                :value => manifest["Value"].strip
            )
          end
        else
          model.manifests = []
        end
        model.not_new_model!
        model
      end
    end
    # save current model
    # @return [True,False]
    def save
      type = (@new_record == true) ? :post : :put
      OATClient::request(type, :path => "/WLMService/resources/mles", :params => {
          :Name => name,
          :Version => version,
          :OsName => os_name,
          :OsVersion => os_version,
          :Attestation_Type => attestation_type,
          :MLE_Type => mle_type,
          :Description => description,
          :OemName => oem_name,
          :MLE_Manifests => (manifests ? manifests.collect {|manifest| { :Name => manifest.name, :Value => manifest.value } } : nil)
      })
    end
    # delete current model
    # @return [True,False]
    def delete
      #TODO: Fix too late. OAT server cant delete entry with error: {"error_code":"1007","error_message":"WLM Service Error - MLE not found in attestation data to delete"}
      OATClient::request(:delete, :path =>   "/WLMService/resources/mles", :query => {
          :mleName => name,
          :mleVersion => version,
          :oemName => oem_name,
          :osName => os_name,
          :osVersion => os_version,
      })
    end
    # search models by params
    def self.search params = {}
      super all, params
    end
    # add new manifest for current model
    def add_manifest params
      @manifests ||= []
      @manifests << MLE::Manifest.new(params)
    end
    # search manifests in current model by params
    # @return [Array<OATClient::Manifest>]
    def search_manifests params = {}
      super manifests, params
    end
  end

  # class for work with models of manifests (PCR)
  class MLE::Manifest < Base
    attr_accessor :name, :value
  end

end
