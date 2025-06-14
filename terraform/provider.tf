provider "aws" {
  profile = "sandbox-developer"
  region  = "ap-northeast-1"
  default_tags {
    tags = var.default_tags
  }
}
