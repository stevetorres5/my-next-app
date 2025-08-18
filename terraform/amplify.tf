
data "aws_ssm_parameter" "ssm_githubtoken" {
  name            = "/${local.ssm_path}/githubtoken"
  with_decryption = true
}

resource "aws_amplify_app" "app" {
  name                        = "my-app"
  repository                  = "https://github.com/${var.github_owner}/${var.github_repo}"
  enable_auto_branch_creation = false
  enable_branch_auto_deletion = false
  access_token                = data.aws_ssm_parameter.ssm_githubtoken.value

  iam_service_role_arn = aws_iam_role.amplify_service_role.arn

  platform   = "WEB_COMPUTE"
  build_spec = file("${path.module}/amplify.yml")

  auto_branch_creation_config {
    enable_auto_build = false
  }

  custom_rule {
    source = "/<*>"
    target = "/index.html"
    status = "404"
  }

}

resource "aws_amplify_branch" "main" {
  app_id            = aws_amplify_app.app.id
  branch_name       = "main"
  enable_auto_build = true

  stage = "DEVELOPMENT"

  environment_variables = {
    APP_ENV = "DEVELOPMENT"
  }
}

resource "null_resource" "trigger_amplify_deployment" {
  depends_on = [aws_amplify_branch.main]

  triggers = {
    app_id = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "aws amplify start-job --app-id ${aws_amplify_app.app.id} --branch-name ${aws_amplify_branch.main.branch_name} --job-type RELEASE"
  }
}