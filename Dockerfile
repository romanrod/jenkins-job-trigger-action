FROM ruby



COPY jenkins /jenkins
COPY jenkins_job.rb /jenkins_job.rb

RUN bundle install

ENTRYPOINT [ "ruby", "/jenkins_job.rb" ]
