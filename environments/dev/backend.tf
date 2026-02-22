# Remote backend - create the S3 bucket before init, then run: terraform init -backend-config=backend.dev.hcl
# Example backend.dev.hcl (do not commit): bucket = "your-tfstate-bucket"
terraform {
  backend "s3" {
    key     = "dev/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
