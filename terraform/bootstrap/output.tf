output "aws_iam_openid_connect_provider" {
    value = aws_iam_openid_connect_provider.openid_provider.id
}

output "aws_iam_role" {
    value = aws_iam_role.terraform_assumable_role.id
}

output "aws_iam_role_policy_attachment" {
    value = aws_iam_role_policy_attachment.amplify_admin_policy_attachment.id
}

output "aws_iam_role_policy" {
    value = aws_iam_role_policy.terraform_assumable_role_inline_policy.id
}