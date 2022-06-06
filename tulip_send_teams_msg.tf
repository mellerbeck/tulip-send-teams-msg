# Creating IAM role so that Lambda service to assume the role and access other 

variable "tulip_send_teams_msg_function_name" {
  default = "tulip-send-teams-msg"
}


resource "aws_iam_role" "tulip_send_teams_msg_lambda_role" {
  name               = "${var.tulip_send_teams_msg_function_name}-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Create the log group 
resource "aws_cloudwatch_log_group" "tulip_send_teams_msg_log_group" {
  name              = "/aws/lambda/${var.tulip_send_teams_msg_function_name}"
  retention_in_days = 14
}

# Generates an archive from content, a file, or a directory of files.

data "archive_file" "tulip_send_teams_msg_zipit" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/tulip_send_teams_msg/code"
  output_path = "${path.module}/lambdas/tulip_send_teams_msg/zippedcode/lambda_function_payload.zip"
}


resource "aws_lambda_function" "tulip_send_teams_msg_lambdafunc" {
  filename      = "${path.module}/lambdas/tulip_send_teams_msg/zippedcode/lambda_function_payload.zip"
  source_code_hash = "${data.archive_file.tulip_send_teams_msg_zipit.output_base64sha256}"
  function_name = var.tulip_send_teams_msg_function_name
  layers        = ["${data.aws_ssm_parameter.psycopg2_layer.value}"]
  memory_size   = 256
  timeout       = 15
  role          = aws_iam_role.tulip_send_teams_msg_lambda_role.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.8"
  depends_on    = [aws_iam_role_policy_attachment.tulip_send_teams_msg_policy_attach]


}

resource "aws_lambda_function_event_invoke_config" "tulip_send_teams_msg_invoke_config" {
  function_name                = "${aws_lambda_function.tulip_send_teams_msg_lambdafunc.arn}"
  maximum_retry_attempts       = 0
}

# Policies

resource "aws_iam_policy" "tulip_send_teams_msg_lambda_logging" {

  name        = "${var.tulip_send_teams_msg_function_name}-policy"
  path        = "/"
  description = "IAM policy for logging from a lambda"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [

        {
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : [
            "arn:aws:logs:${data.aws_region.current.name}:${local.account_id}:log-group:/aws/lambda/${var.tulip_send_teams_msg_function_name}:*"
          ]
        }
      ]
    }
  )
}

# Policy Attachment on the role.

resource "aws_iam_role_policy_attachment" "tulip_send_teams_msg_policy_attach" {
  role       = aws_iam_role.tulip_send_teams_msg_lambda_role.name
  policy_arn = aws_iam_policy.tulip_send_teams_msg_lambda_logging.arn
}

resource "aws_iam_policy" "tulip_send_teams_msg_ssm_access" {

  name        = "SSMReadOnlyAccess_${var.tulip_send_teams_msg_function_name}-policy"
  path        = "/"
  description = "IAM policy for SSMReadOnlyAccess"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "ssm:DescribeParameters",
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "ssm:GetParameter",
            "Resource": "arn:aws:ssm:${data.aws_region.current.name}:${local.account_id}:parameter/${var.ssm_path}/teamsintegration/channels"
        }
    ]
    }
  )
}

# Policy Attachment on the role.

resource "aws_iam_role_policy_attachment" "tulip_send_teams_msg_policy_attach_ssm" {
  role       = aws_iam_role.tulip_send_teams_msg_lambda_role.name
  policy_arn = aws_iam_policy.tulip_send_teams_msg_ssm_access.arn
}