/*
    * 予算アラートのSNSトピックを作成し、メール通知を設定する
    * SNSトピックに予算アラートのポリシーを設定し、AWS Budgetsからの通知を許可する
    * 月間予算を設定し、90%の予算に達した場合にSNSトピックとメールアドレスに通知する
    * AWS Chatbotを設定し、SNSトピックからの通知をSlackチャンネルにも送信する
*/
resource "aws_sns_topic" "budget_alert" {
  name = "budget-alert-topic"
}

resource "aws_sns_topic_subscription" "budget_alert_email" {
  topic_arn = aws_sns_topic.budget_alert.arn
  protocol  = "email"
  endpoint  = var.budget_alert_email_address
}

resource "aws_sns_topic_policy" "budget_alert_policy" {
  arn = aws_sns_topic.budget_alert.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBudgetToPublish"
        Effect = "Allow"
        Principal = {
          Service = "budgets.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.budget_alert.arn
      }
    ]
  })
}

resource "aws_budgets_budget" "sandbox_monthly" {
  name         = "sandbox-monthly-budget"
  budget_type  = "COST"
  time_unit    = "MONTHLY"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"

  cost_filter {
    name   = "LinkedAccount"
    values = [var.budget_alert_account_id]
  }

  notification {
    notification_type          = "FORECASTED" # 予算の予測値に基づく通知（超えそうだったら通知）
    threshold_type             = "PERCENTAGE"
    threshold                  = 90
    comparison_operator        = "GREATER_THAN" # 予算の90%を超えた場合に通知
    subscriber_email_addresses = [var.budget_alert_email_address]
    subscriber_sns_topic_arns  = [aws_sns_topic.budget_alert.arn]
  }
}

resource "aws_budgets_budget" "sandbox_monthly_actual" {
  name         = "sandbox-monthly-budget-actual"
  budget_type  = "COST"
  time_unit    = "MONTHLY"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"

  cost_filter {
    name   = "LinkedAccount"
    values = [var.budget_alert_account_id]
  }

  notification {
    notification_type          = "ACTUAL"
    threshold_type             = "PERCENTAGE"
    threshold                  = 90
    comparison_operator        = "GREATER_THAN" # 予算の90%を超えた場合に通知
    subscriber_email_addresses = [var.budget_alert_email_address]
    subscriber_sns_topic_arns  = [aws_sns_topic.budget_alert.arn]
  }
}


resource "aws_iam_role" "chatbot_role" {
  name = "AWSchatbotServiceRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "chatbot.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "chatbot_sns_policy" {
  name = "ChatbotSNSAccess"
  role = aws_iam_role.chatbot_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sns:ListTopics",
          "sns:ListSubscriptionsByTopic",
          "sns:GetTopicAttributes",
          "sns:Subscribe"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_chatbot_slack_channel_configuration" "budget_alert_slack" {
  configuration_name = "budget-alert-to-slack"

  iam_role_arn     = aws_iam_role.chatbot_role.arn
  slack_channel_id = var.slack_channel_id             # Slackチャンネル or DM の ID
  slack_team_id    = var.slack_team_id                # SlackワークスペースのID
  sns_topic_arns   = [aws_sns_topic.budget_alert.arn] # 既存のSNSトピックを使う

  logging_level = "ERROR"
}

/*
  * ECRレポジトリの作成
  * ECRレポジトリのライフサイクルポリシーを設定
  * ライフサイクルポリシーで、イメージのタグが「any」で、プッシュから5日以上経過したイメージを削除する
  * ECRレポジトリのイメージを使用してLambda関数をデプロイする
*/
resource "aws_ecr_repository" "nuke_lambda" {
  name                 = "nuke-lambda"
  image_tag_mutability = "MUTABLE"

  tags = {
    Name = "nuke-lambda-repository"
  }
}

resource "aws_ecr_lifecycle_policy" "nuke_lambda_policy" {
  repository = aws_ecr_repository.nuke_lambda.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire images older than 5 days"
        selection = {
          tagStatus   = "any"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_lambda_function" "nuke_lambda" {
  function_name = "nuke-lambda"
  package_type  = "Image"
  image_uri     = var.lambda_image_uri
  role          = aws_iam_role.nuke_lambda_exec.arn
  timeout       = 900 # 15 minutes timeout
  memory_size   = 3008

  depends_on = [
    aws_ecr_repository.nuke_lambda,
    aws_ecr_lifecycle_policy.nuke_lambda_policy
  ]

  environment {
    variables = {
      SLACK_CHANNEL_ID   = var.slack_channel_id
      SLACK_TEAM_ID      = var.slack_team_id
      SNS_TOPIC_ARN      = aws_sns_topic.budget_alert.arn
      BUDGET_LIMIT_USD   = tostring(var.budget_limit_usd)
      BUDGET_ALERT_EMAIL = var.budget_alert_email_address
    }
  }
}

resource "aws_iam_role" "nuke_lambda_exec" {
  name = "nuke-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "nuke-lambda-role"
  }
}

resource "aws_iam_role_policy_attachment" "nuke_lambda_logs" {
  role       = aws_iam_role.nuke_lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "assume_nuke_role" {
  name = "AllowAssumeNukeExecutionRole"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "sts:AssumeRole",
        Resource = var.nuke_execution_role
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:*",
          "iam:*"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_assume_nuke" {
  role       = aws_iam_role.nuke_lambda_exec.name
  policy_arn = aws_iam_policy.assume_nuke_role.arn
}

/*
  * 
*/
resource "aws_iam_role" "lambda_role" {
  name = "lambda_account_id_check_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_account_id_check_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "organizations:ListAccounts"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = "arn:aws:iam::*:role/AWSControlTowerExecution"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:ListAccountAliases"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# ソースコードを自動ZIP
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/check_account_id"
  output_path = "${path.module}/../check_account_id.zip"
}

resource "aws_lambda_function" "org_alias_lambda" {
  function_name = "account_id_check"
  role          = aws_iam_role.lambda_role.arn
  handler       = "check_account_id.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}
