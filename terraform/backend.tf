
terraform {
  backend "s3" {
    bucket  = "my-bucket-lockin"
    key     = "terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
