resource "src-repo": {
  type: "git"
  param url: "$(context.git.url)"
  param revision: "$(context.git.commit)"
}

resource "gcr-image": {
  type: "image"
  param url: "gcr.io/massive-bliss-781/devx-dispatch-demo"
}

task "unit-test": {
  inputs: ["src-repo"]
  steps: [
    {
      name: "go-test"
      image: "golang:1.13.0-buster"
      command: ["go", "test", "./..."]
      workingDir: "/workspace/src-repo"
      env: [
        {
          name: "SLEEP_DURATION"
          value: "5s"
        }
      ]
    }
  ]
}

task "build-image": {
  inputs: ["src-repo"]
  outputs: ["gcr-image"]
  deps: ["unit-test"]
  steps: [
    {
      name: "build-and-push"
      image: "gcr.io/kaniko-project/executor"
      args: [
        "--destination=$(outputs.resources.gcr-image.url)",
        "--context=/workspace/src-repo",
        "--oci-layout-path=/builder/home/image-outputs/gcr-image",
        "--dockerfile=/workspace/src-repo/Dockerfile",
        "--cache=true",
        "--cache-ttl=10h"
      ]
      env: [
        {
          name: "GOOGLE_APPLICATION_CREDENTIALS"
          value: "/builder/volumes/gcloud-auth/key.json"
        }
      ]
    }
  ]
  volumes: [
    {
      name: "gcloud-auth"
      secret: {
        secretName: "devx-gcloud-auth"
      }
    }
  ]
}

task "integration-test": {
  inputs: ["gcr-image"]
  steps:[
    {
      name: "run-test"
      image: "$(inputs.resources.gcr-image.url)@$(inputs.resources.gcr-image.digest)"
      command: ["/hello-app.test"]
      env: [
        {
          name: "SLEEP_DURATION"
          value: "5s"
        }
      ]
    }
  ]
}

task "deploy": {
  inputs: ["gcr-image"]
  deps: ["integration-test"]
  steps: [
    {
      name: "gcloud-auth-sa"
      image: "gcr.io/cloud-builders/gcloud"
      args: [
        "auth",
        "activate-service-account",
        "devx-onprem-sa@massive-bliss-781.iam.gserviceaccount.com",
        "--key-file=/builder/volumes/gcloud-auth/key.json",
        "--quiet"
      ]
    },
    {
      name: "gcloud-run"
      image: "gcr.io/cloud-builders/gcloud"
      args: [
        "run",
        "deploy",
        "devx-dispatch-demo",
        "--project=massive-bliss-781",
        "--image=gcr.io/massive-bliss-781/devx-dispatch-demo",
        "--region=us-central1",
        "--platform=managed",
        "--quiet"
      ]
    }
  ]
  volumes: [
    {
      name: "gcloud-auth"
      secret: {
        secretName: "devx-gcloud-auth"
      }
    }
  ]
}

actions: [
  {
    tasks: ["deploy"]
    on push: {
      branches: ["gcloud"]
    }
  },
  {
    tasks: ["integration-test"]
    on pull_request: {}
  }
]
