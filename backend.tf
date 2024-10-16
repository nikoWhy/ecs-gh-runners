terraform {
  backend "s3" {
    key    = "tfstate"
    region = "eu-central-1"
  }
}
