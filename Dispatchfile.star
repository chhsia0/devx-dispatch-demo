#!starlark

gitResource("src-repo",
    url="$(context.git.url)",
    revision="$(context.git.commit)"
)

gitResource("gitops-repo",
    url="https://github.com/chhsia0/devx-dispatch-gitops-demo",
    revision="master"
)

imageResource("docker-image",
    url="chhsiao/devx-dispatch-demo"
)

task("unit-test",
    inputs=["src-repo"],
    steps=[v1.Container(
        name="go-test",
        image="golang:1.13.0-buster",
        command=["go", "test", "./..."],
        workingDir="/workspace/src-repo",
        env=[v1.EnvVar(name="SLEEP_DURATION", value="1s")]
    )]
)

task("build-image",
    inputs=["src-repo"],
    outputs=["docker-image"],
    deps=["unit-test"],
    steps=[v1.Container(
        name="build-and-push",
        image="gcr.io/kaniko-project/executor",
        args=[
            "--destination=$(outputs.resources.docker-image.url)",
            "--context=/workspace/src-repo",
            "--oci-layout-path=/builder/home/image-outputs/docker-image",
            "--dockerfile=/workspace/src-repo/Dockerfile"
        ],
        env=[v1.EnvVar(name="DOCKER_CONFIG", value="/builder/home/.docker")]
    )]
)

task("integration-test",
    inputs=["docker-image"],
    steps=[v1.Container(
        name="run-test",
        image="$(inputs.resources.docker-image.url)@$(inputs.resources.docker-image.digest)",
        command=["/hello-app.test"],
        env=[v1.EnvVar(name="SLEEP_DURATION", value="1s")]
    )]
)

task("deploy",
    inputs=["docker-image", "gitops-repo"],
    deps=["integration-test"],
    steps=[v1.Container(
        name="update-gitops-repo",
        image="mesosphere/update-gitops-repo:v1.0",
        workingDir="/workspace/gitops-repo",
        args=[
            "-git-revision=$(context.git.commit)",
            "-substitute=imageName=$(inputs.resources.docker-image.url)@$(inputs.resources.docker-image.digest)"
        ]
    )]
)

action(tasks=["deploy"], on=push(branches=["master"]))
action(tasks=["integration-test"], on=pullRequest(chatops=["test"]))
