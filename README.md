# Production EKS Microservices Infrastructure

Professional-grade infrastructure-as-code (Terraform) and Kubernetes orchestration for a secure, scalable, and observable microservices cluster on AWS. This project demonstrates modern cloud-native patterns including **EKS Pod Identity**, **Secrets Store CSI Driver**, and **ALB Ingress Grouping**.

## 🏗️ Architecture

- **EKS Cluster**: Private endpoint access with nodes in private subnets for maximum security.
- **Networking**: VPC-native networking via Amazon VPC CNI. External traffic enters through a shared Application Load Balancer (ALB).
- **Authentication**: Native **EKS Pod Identity** (migrated from IRSA) for all cluster components (CSI drivers, Autoscaler, Fluent Bit, and Application Pods).
- **Secrets Management**: **AWS Secrets Manager** integrated via the **Secrets Store CSI Driver**. Secrets are mounted as volumes and synced to Kubernetes secrets for environment variable injection.
- **Database**: **Amazon RDS MySQL** instance restricted to internal VPC traffic.
- **Storage**: Amazon S3 for frontend hosting (CloudFront) and microservice file uploads.
- **Observability**: Fully automated deployment of the **Kube-Prometheus-Stack** (Prometheus & Grafana) and **AWS for Fluent Bit** (CloudWatch Logs).

---

## 🚀 Deployment Prerequisites

1. **AWS CLI & Terraform**: Installed and configured with appropriate permissions.
2. **Custom Domain**: Managed via Route 53 or external registrar (e.g., Hostinger).
3. **S3 Backend**: Manually create an S3 bucket to host the Terraform state.

---

## 🛠️ Step 1: Infrastructure Provisioning

1. Initialize the backend:
   ```bash
   cd environments/dev
   cp backend.dev.hcl.example backend.dev.hcl # Set your bucket name
   terraform init -backend-config=backend.dev.hcl
   ```
2. Configure your environment:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Fill in your domain_name, db_credentials, and name_prefix
   ```
3. Deploy the stack:
   ```bash
   terraform apply -var-file="terraform.tfvars"
   ```

---

## 🔐 Step 2: Secrets & Database Setup (Bastion Host)

Since the cluster is private, management tasks are performed via the **Bastion Host**.

1. **Initialize RDS**: Connect to RDS and create the application databases:
   ```sql
   CREATE DATABASE login_db;
   CREATE DATABASE file_db;
   ```
2. **Set Secret Values**: Navigate to AWS Secrets Manager and update the provisioned secret (`<prefix>-app-secrets`) with your plaintext database credentials and application keys.

---

## 📦 Step 3: Kubernetes Deployment

1. **Sanitize Manifests**: All files in `kubernetes/` use placeholders. Update these with your specific values:
   - `app-config.yaml`: Update `<YOUR_RDS_ENDPOINT>` and `<YOUR_S3_BUCKET_NAME>`.
   - `*-ingress.yaml`: Update `<YOUR_ACM_CERTIFICATE_ARN>`.
   - `secret-provider.yaml`: Update `<YOUR_SECRET_NAME>`.
   - `*-service.yaml`: Update `<YOUR_ECR_IMAGE_URI>`.

2. **Apply Manifests**:
   ```bash
   kubectl apply -f kubernetes/namespace.yaml
   kubectl apply -f kubernetes/storage-class.yaml
   kubectl apply -f kubernetes/app-sa.yaml
   kubectl apply -f kubernetes/app-config.yaml
   kubectl apply -f kubernetes/secret-provider.yaml
   kubectl apply -f kubernetes/login-service.yaml
   kubectl apply -f kubernetes/file-service.yaml
   kubectl apply -f kubernetes/login-ingress.yaml
   kubectl apply -f kubernetes/file-ingress.yaml
   ```

---

## 📊 Observability

- **Grafana**: Accessible at `https://<YOUR_DOMAIN>/grafana/`. (Credentials set via `grafana_admin_password` in Terraform).
- **Logging**: Application logs are automatically streamed to **CloudWatch Logs** under the group `/eks/<prefix>/containers`.

---

## 🧹 Cleanup & Teardown

To avoid ongoing charges, ensure resources are deleted in the following order:

1. **Kubernetes Cleanup** (Bastion):
   ```bash
   kubectl delete -f kubernetes/.
   ```
2. **Terraform Cleanup** (Local):
   ```bash
   terraform destroy -var-file="terraform.tfvars"
   ```

---

## 👨‍💻 Security Design Implementations
- **Zero Public Access**: All compute and data resources reside in private subnets.
- **IMDSv2 Enforced**: Node launch templates require session tokens and restrict hop limit.
- **Least Privilege**: Migrated from shared node roles to granular Pod Identities.
- **Encrypted Traffic**: HTTPS enforced at the ALB level via ACM SSL certificates.