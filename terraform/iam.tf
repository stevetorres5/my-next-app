resource "aws_iam_role" "amplify_service_role" {
  name = "Essaypop-AmplifyServiceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = ["amplify.amazonaws.com","amplify.us-west-2.amazonaws.com"]
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudwatch_logs" {
    name = "Essaypop-CloudWatchLogsAccess"
    role = aws_iam_role.amplify_service_role.arn

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid = "CloudWatchLogsAccess"
                Effect = "Allow"
                Action = [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:DescribeLogGroups",
                    "logs:DescribeLogStreams",
                    "logs:PutLogEvents"
                ]
                Resource = "*"
            }
        ]
    })
  
}