# jenkins-job-trigger-action

Triggers Jenkins Jobs from GitHub actions

This action allows to trigger a job on Jenkins and get the build result.

```
name: Your GHA
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  your_job_name:
    name: Trigger Jenkins Job
    runs-on: ubuntu-latest
    steps:
      - name: Trigger your-awesome-job-name job
        uses: romanrod/jenkins-job-trigger-action@master
        with:
          jenkins_url: "https://your.jenkins.url/"
          jenkins_user: "your-jenkins-username"
          jenkins_token: "the-token-you-created-on-job-settings"
          job_name: "the-name-of-your-jenkins-job"
          job_params: '{"param_1":"value_1", "param_2":"value_2"}'
          job_timeout: "3600" # Default 30 sec. (optional)
```
