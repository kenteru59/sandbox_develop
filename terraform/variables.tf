variable "default_tags" {
  description = "共通タグ"
  type        = map(string)
}

variable "budget_alert_email_address" {
  description = "予算通知を送るメールアドレス"
  type        = string
}

variable "budget_limit_usd" {
  description = "月間予算上限（USD）"
  type        = number
}

variable "budget_alert_account_id" {
  description = "予算アラートの対象AWSアカウントのID"
  type        = string
}

variable "slack_channel_id" {
  description = "Slack通知を受け取るチャンネルID"
  type        = string
}

variable "slack_team_id" {
  description = "Slack通知を受け取るワークスペースのID"
  type        = string
}
