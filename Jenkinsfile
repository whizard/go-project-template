#!groovy

import groovy.json.JsonOutput

def PROJECT = "My Project"
def SLACK_CHAN = "MySlackChannel"

def notifySlack(text, channel) {
    def slackURL = 'https://hooks.slack.com/services/xxxxxxx/yyyyyyyy/zzzzzzzzzz'
    def payload = JsonOutput.toJson([text      : text,
                                     channel   : channel,
                                     username  : "jenkins",
                                     icon_emoji: ":jenkins:"])
    sh "curl -X POST --data-urlencode \'payload=${payload}\' ${slackURL}"
}

def checkout () {
    stage 'Checkout code'
    checkout scm
}

def build () {
    stage 'Build'
    try {
        make build
    } catch (err) {
        notifySlack("${PROJECT} - Build Failed", ${SLACK_CHAN})
    }
}

def unitTests() {
    stage 'Unit tests'
    try {
        make tests
    } catch (err) {
        notifySlack("${PROJECT} - Unit Tests Failed", ${SLACK_CHAN})
    }
}

def allTests() {
    stage('AllTest') {
      parallel {
        stage ('Unit test'){
            unitTests()
        }
        // run Sonar Scan and Integration tests in parallel. This syntax requires Declarative Pipeline 1.2 or higher
        stage ('Integration Test') {
          agent any  //run this stage on any available agent
          steps {
            echo 'Run integration tests here...'
          }
        }
        stage('Sonar Scan') {
          steps {
            echo 'Run Sonar Scan here...'
          }
        }
      }
    }
}

def publish() {
    stage "Publish Image"
    try {
        make publish
    } catch (err) {
        echo "Build Failed"
        notifySlack("${PROJECT} - Build Failed", ${SLACK_CHAN})
    }
}

def deployToDev() {
    stage "Deploy to Dev"
    try {
        make deploy-dev
    } catch (err) {
        echo "Deployment to Dev Failed"
        notifySlack("${PROJECT} - Dev Deployment Failed", ${SLACK_CHAN})
    }
}

def deployToStage() {
    stage "Deploy to Stage"
    input "Deploy to Stage?"
    try {
        make deploy-stage
    } catch (err) {
        echo "Deployment to Stage Failed"
        notifySlack("${PROJECT} - Stage Deployment Failed", ${SLACK_CHAN})
    }
}

def deployToProd() {
    stage "Deploy to Production"
    input "Deploy to Production?"
    try {
        make deploy-prod
    } catch (err) {
        echo "Deployment to Production Failed"
        notifySlack("${PROJECT} - Production Deployment Failed", ${SLACK_CHAN})
    }
}

node {   
    // pull request or feature branch
    if  (env.BRANCH_NAME != 'master') {
        checkout()
        build()
        unitTests()
        deployToDev()
    } // master branch / production
    else { 
        checkout()
        build()
        allTests()
        publish()
        deployToDev()
        deployToStage()
        deployToProd()
    }
}