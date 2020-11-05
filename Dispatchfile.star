#!mesosphere/dispatch-starlark:v0.8

load("github.com/mesosphere/dispatch-catalog/starlark/stable/kaniko@0.0.9", "kaniko")
load("github.com/mesosphere/dispatch-catalog/starlark/stable/pipeline@0.0.9", "image_resource", "image_reference", "push", "pull_request")
load("github.com/mesosphere/dispatch-catalog/starlark/stable/git@0.0.9", "git_resource", "git_checkout_dir", "git_revision")

src_repo = git_resource("src-repo")

gitops_repo = git_resource("gitops-repo",
    url="https://github.com/chhsia0/devx-dispatch-gitops-demo",
    revision="master"
)

docker_image = kaniko("build-image", src_repo, "chhsiao/devx-dispatch-demo")

task("test",
    inputs=[docker_image],
    steps=[v1.Container(
        name="test",
        image=image_reference(docker_image),
        command=["/hello-app.test"],
        env=[v1.EnvVar(name="SLEEP_DURATION", value="1s")]
    )]
)

task("deploy",
    inputs=[docker_image, gitops_repo, "test"],
    steps=[v1.Container(
        name="update-gitops",
        image="mesosphere/update-gitops-repo:1.3.0",
        workingDir=git_checkout_dir(gitops_repo),
        args=[
            "-git-revision=$(context.git.commit)",
            "-substitute=imageName={}".format(image_reference(docker_image))
        ]
    )]
)

action(tasks=["deploy"], on=push(branches=["master"]))
action(tasks=["test"], on=pull_request(targets=["master"]))
action(tasks=["test"], on=pull_request(targets=["master"], chatops=["test"]))
