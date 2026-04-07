terraform {
  backend "s3" {
    bucket         = "labhub-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "ap-southeast-1"
    use_lockfile   = true
    encrypt        = true
  }
}
