resource "src-repo": {
  type: "git"
  param url: "$(context.git.url)"
  param revision: "$(context.git.commit)"
}

resource "gitops-repo": {
  type: "git"
  param url: "https://github.com/mesosphere/devx-dispatch-gitops-demo"
}

resource "docker-image": {
  type: "image"
  param url: "mesosphere/devx-dispatch-demo"
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
  outputs: ["docker-image"]
  deps: ["unit-test"]

  steps: [
    {
      name: "build-and-push"
      image: "gcr.io/kaniko-project/executor"
      args: [
        "--destination=$(outputs.resources.docker-image.url)",
        "--context=/workspace/src-repo",
        "--oci-layout-path=/builder/home/image-outputs/docker-image",
        "--dockerfile=/workspace/src-repo/Dockerfile"
      ],
      env: [
        {
          name: "DOCKER_CONFIG"
          value: "/builder/home/.docker"
        }
      ]
    }
  ]
}

task "integration-test": {
  inputs: ["docker-image"]

  steps:[
    {
      name: "run-test"
      image: "$(inputs.resources.docker-image.url)@$(inputs.resources.docker-image.digest)"
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
  inputs: ["docker-image", "gitops-repo"]
  deps: ["integration-test"]

  steps: [
    {
      name: "update-gitops-repo"
      image: "mesosphere/update-gitops-repo:v1.0"
      workingDir: "/workspace/gitops-repo"
      args: [
        "-git-revision=$(context.git.commit)",
        "-substitute=imageName=$(inputs.resources.docker-image.url)@$(inputs.resources.docker-image.digest)"
      ]
    }
  ]
}

actions: [
  {
    tasks: ["deploy"]
    on push: {
      branches: ["master"]
    }
  },
  {
    tasks: ["integration-test"]
    on pull_request: {
      chatops: ["test"]
    }
  }
]
