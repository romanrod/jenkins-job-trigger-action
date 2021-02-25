require_relative 'jenkins/job_client'
Jenkins::JobClient.new(ENV).call
