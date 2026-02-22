# eks-infra

Terraform for EKS app infrastructure: VPC, S3, CloudFront (frontend), RDS MySQL, ECR, and bastion host.

## Layout

- **modules/** – Reusable modules: `vpc`, `s3`, `ecr`, `rds`, `bastion`, `cloudfront`
- **environments/dev/** – Dev environment (us-east-1, prefix e.g. `myapp-ue1-dev-eks-app`)

## Backend

Use S3 for remote state (no DynamoDB). Create the bucket yourself, then configure:

1. Create state bucket (one-time):

   ```bash
   aws s3 mb s3://YOUR-STATE-BUCKET --region us-east-1
   ```

2. In `environments/dev/`, copy `backend.dev.hcl.example` to `backend.dev.hcl` and set `bucket`.

3. Init with backend config:

   ```bash
   cd environments/dev
   terraform init -backend-config=backend.dev.hcl
   ```

## Dev usage

1. `cd environments/dev`
2. Copy `terraform.tfvars.example` to `terraform.tfvars` and set:
   - `name_prefix` (e.g. `myapp-ue1-dev-eks-app`)
   - `bastion_ssh_cidr`, `bastion_key_name`
   - `db_username`, `db_password`
3. Ensure an EC2 key pair named in `bastion_key_name` exists in us-east-1.
4. Run:

   ```bash
   terraform plan
   terraform apply
   ```

## Outputs

- **Frontend:** CloudFront URL (origin: `{name_prefix}-dev-ui` S3 bucket)
- **ECR:** `login-service`, `file-service` repository URLs
- **RDS:** Endpoint (connect via bastion)
- **Bastion:** Public IP and example SSH command

## Deploying the UI

Upload your frontend build to the UI bucket so CloudFront serves it:

```bash
aws s3 sync ./dist s3://$(terraform -chdir=environments/dev output -raw ui_bucket_name) --delete
```
