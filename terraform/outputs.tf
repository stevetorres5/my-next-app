output "amplify_app_id" {
  value = aws_amplify_app.app.id
}

output "amplify_default_branch_url" {
  value = aws_amplify_app.app.default_domain
}
