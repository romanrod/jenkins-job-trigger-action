require 'rest-client'
require 'json'
# require 'byebug'
# require 'oauth'
module Jenkins
  class JobClient

    attr_reader :jenkins_url, :jenkins_user, :jenkins_token, :job_name, :job_params, :job_timeout

    DEFAULT_TIMEOUT = 30
    INTERVAL_SECONDS = 10
    IN_PROGRESS_MESSAGE = nil
    SUCCESS_MESSAGE = "SUCCESS"

    def initialize(args)
      @jenkins_url = args["JENKINS_URL"]
      @jenkins_user = args["JENKINS_USER"]
      @jenkins_token = args["JENKINS_TOKEN"]
      @job_name = args["JOB_NAME"]
      @job_params = JSON.parse(args["JOB_PARAMS"])
      @job_timeout = args['JOB_TIMEOUT'] || DEFAULT_TIMEOUT
    end

    def call
      crumb = get_crumb
      queue_item_location = queue_job(crumb, job_name, job_params)
      job_run_url = get_job_run_url(queue_item_location, job_timeout)
      puts "Job run URL: #{job_run_url}"
      job_progress(job_run_url, job_timeout)
      exit(0)
    end

    def perform_request(url, method = :get, **args)
      response = RestClient::Request.execute method: method, url: url, user: jenkins_user, password: jenkins_token, args: args
      response_code = response.code
      raise "Error on #{method} request to #{url} [Error code: #{response_code}]" unless (200..299).include? response_code
      response
    end


    def get_crumb
      response = perform_request("#{jenkins_url}/crumbIssuer/api/json", headers: {'content-type': 'application/json'})
      JSON.parse(response)['crumb']
    end


    def queue_job(crumb, job_name, job_params)
      query_string = ''
      job_params.each_pair{|k,v| query_string +="#{k}=#{v}&"} if job_params
      job_queue_url = "#{jenkins_url}job/#{job_name}/buildWithParameters?#{query_string}".chop
      queue_response = perform_request(job_queue_url, :post, params: { 'token': jenkins_token }, headers: {'Jenkins-Crumb': crumb})
      queue_item_location = queue_response.headers[:location]
      queue_item_location
    end


    def get_job_run_url(queue_item_location, job_timeout = DEFAULT_TIMEOUT)
      job_run_url = nil
      job_timeout = job_timeout.to_i if job_timeout.is_a? String
      timeout_countdown = job_timeout

      while job_run_url.nil? and timeout_countdown > 0
        begin
          job_run_response = perform_request("#{queue_item_location}api/json", :get)
          job_run_response_executable = nil
          job_run_response_executable = JSON.parse(job_run_response)["executable"]
          if job_run_response_executable
            job_run_url = job_run_response_executable["url"]
          end
        rescue
          # NOOP
        end
        if job_run_url.nil?
            timeout_countdown = timeout_countdown - sleep(INTERVAL_SECONDS)
        end
      end

      if job_run_url
          return job_run_url
      elsif timeout_countdown == 0
          puts "JOB TRIGGER TIMED OUT (After #{job_timeout} seconds)"
          exit(1)
      else
          puts "JOB TRIGGER FAILED."
          exit(1)
      end
      job_run_url
    end

    def job_progress(job_run_url, job_timeout = DEFAULT_TIMEOUT)
      job_timeout = job_timeout.to_i if job_timeout.is_a? String
      job_progress_url = "#{job_run_url}api/json"
      job_log_url = "#{job_run_url}logText/progressiveText"

      build_response = nil
      build_result = IN_PROGRESS_MESSAGE
      timeout_countdown = job_timeout
      while build_result == IN_PROGRESS_MESSAGE and timeout_countdown > 0
        begin
            build_response = perform_request(job_progress_url, :get)
            result = JSON.parse(build_response)["result"]
            build_result = result || build_result
        rescue
            # "NOOP"
        end
        if build_result == IN_PROGRESS_MESSAGE
            timeout_countdown = timeout_countdown - sleep(INTERVAL_SECONDS)
        elsif build_result == "ABORTED"
          puts "JOB ABORTED"
          exit(1)
        end
      end
      if build_result == "SUCCESS"
          puts "DDL validation with SUCCESS status!"
      elsif timeout_countdown == 0
          puts "JOB FOLLOW TIMED OUT (After #{job_timeout} seconds)"
          exit(1)
      else
        puts "DDL validation with {build_result} status."
        begin
            log_response = perform_request(job_log_url, :get)
            byebug
            # log_response.content.decode('utf8')
            puts log_response
        rescue
            puts "Couldn't retrieve log messages."
        end
        exit(1)
      end
    end
  end
end
