# Production EKS Infrastructure & Deployment Guide

This repository contains the Terraform infrastructure and Kubernetes manifests to deploy a highly available, secure, and scalable microservices architecture (`login-service` and `file-service`) onto AWS Elastic Kubernetes Service (EKS).

## Architecture Overview

**1. Network Security (Private Cluster)**
- **Private EKS Endpoint:** The EKS API server (Control Plane) is private. It cannot be accessed directly from the public internet, preventing external attacks.
- **Private Nodes:** EC2 Worker nodes are deployed in Private Subnets. They pull Docker images from AWS ECR via a NAT Gateway.
- **RDS MySQL:** The database resides in Private Subnets, accessible only from within the VPC.

**2. Administration via Bastion Host**
Since `kubectl` and `mysql` commands cannot reach the private resources from your local machine, a **Bastion Host** (jump box) is provisioned in the public subnet. You must SSH into the Bastion Host to interact with the cluster and database.

**3. AWS Load Balancer Controller (Ingress)**
Traffic from the internet is routed through an **Application Load Balancer (ALB)**, provisioned automatically by the `aws-load-balancer-controller`. 
- The ALB handles SSL termination (HTTPS) using a free **AWS ACM Certificate** validated via your Custom Domain DNS.
- Path-based routing dynamically sends `/files` traffic to the `file-service` and `/` traffic to the `login-service`.

---

## 🚀 Step 1: Provision Infrastructure (Terraform)

### Pre-requisites
1. AWS CLI installed and configured.
2. Terraform installed.
3. An S3 bucket created manually to store the Terraform state.

### Setup
1. Open `environments/dev/backend.dev.hcl.example`, rename it to `backend.dev.hcl`, and set your state bucket name.
2. Open `environments/dev/terraform.tfvars.example`, rename it to `terraform.tfvars`, and configure:
   - `name_prefix` (e.g. `myapp-ue1-dev-eks-app`)
   - `domain_name` (e.g. `yourdomain.com`)
   - `db_username` and `db_password`
   - `bastion_key_name` (Ensure this EC2 key pair exists in `us-east-1`!)

### Deploy
```bash
cd environments/dev
terraform init -backend-config=backend.dev.hcl
terraform apply -var-file="terraform.tfvars"
```

## 🚀 Step 2: Configure Custom Domain (Hostinger / Route 53)
1. Wait for `terraform apply` to finish. It will output `domain_validation_options`.
2. Go to your Domain Registrar (e.g., Hostinger) DNS settings.
3. Add the **CNAME** records specified in the `domain_validation_options` output to validate your AWS ACM Certificate. Wait until the certificate status in AWS changes from `Pending Validation` to `Issued`.

---

## 🚀 Step 3: Configure Database & Kubernetes (Bastion Host)

Everything from this point forward must be run from inside the **Bastion Host**.
Get the Bastion IP from the Terraform outputs and SSH into it:
```bash
ssh -i /path/to/key.pem ec2-user@<BASTION_IP>
```

### 3.1 Initialize MySQL Databases
Connect to your RDS instance using the endpoint provided in the Terraform outputs:
```bash
mysql -h <YOUR_RDS_ENDPOINT> -P 3306 -u <YOUR_DB_USERNAME> -p
```
Run the following SQL commands to create the dedicated databases for your microservices:
```sql
CREATE DATABASE login_db;
CREATE DATABASE file_db;
EXIT;
```

### 3.2 Update `kubeconfig`
Connect your Bastion's `kubectl` CLI to the EKS Cluster:
```bash
aws eks update-kubeconfig --region us-east-1 --name <YOUR_EKS_CLUSTER_NAME>
```

### 3.3 Setup External Secrets Operator (Production Recommended)
To securely manage secrets directly from AWS Secrets Manager without using base64 Kubernetes secrets:
1. Open the AWS Secrets Manager console and navigate to the newly created secret named `<YOUR_NAME_PREFIX>-app-secrets`. Edit the "Secret value" to set your actual plaintext `MYSQL_USER`, `MYSQL_PASSWORD`, and `SECRET_KEY`.
2. Install the ESO operator onto your cluster via Helm:
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets \
    -n external-secrets --create-namespace \
    --set installCRDs=true
```
3. Edit `kubernetes/external-secrets.yaml` and replace `<YOUR_ESO_ROLE_ARN>` and `<YOUR_NAME_PREFIX>` with the values from your Terraform outputs.
4. Apply the External Secrets configuration to automatically sync the AWS Secrets into Kubernetes:
```bash
kubectl apply -f kubernetes/external-secrets.yaml
```

### 3.4 Deploy the Microservices
*Ensure you have copied the `kubernetes/` folder to your Bastion host (e.g., via `git clone` or `scp`).*

1. Edit `kubernetes/app-config.yaml` to include your S3 bucket names and RDS Endpoint.
2. Edit `kubernetes/login-service.yaml` and `file-service.yaml` to replace `<YOUR_AWS_ACCOUNT_ID>` with your 12-digit AWS Account ID.
3. Apply the manifests:
```bash
kubectl apply -f kubernetes/app-config.yaml
kubectl apply -f kubernetes/login-service.yaml
kubectl apply -f kubernetes/file-service.yaml
```

---

## 🚀 Step 4: Install AWS Load Balancer Controller
To expose your services to the internet, you must install the ALB controller. From the Bastion Host, run:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<YOUR_EKS_CLUSTER_NAME> \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<YOUR_ALB_CONTROLLER_ROLE_ARN>
```
*(You can find the `<YOUR_ALB_CONTROLLER_ROLE_ARN>` in the Terraform outputs).*

---

## 🚀 Step 5: Observability & Logging (Metrics & Tracing)
*Run these commands on your Bastion Host to deploy the industry-standard monitoring stack.*

### 5.1 Prometheus & Grafana
Displays compute metrics (CPU/Memory).
1. Edit `kubernetes/observability/prometheus-values.yaml` and set your true `<YOUR_CUSTOM_DOMAIN>`. Keep the `/grafana` sub-path exactly as written.
2. Install the stack via Helm:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace observability --create-namespace \
  -f kubernetes/observability/prometheus-values.yaml
```

### 5.2 AWS Fluent Bit
Streams your application `stdout` logs centrally to AWS CloudWatch Logs.
1. Edit `kubernetes/observability/fluent-bit-values.yaml`. Replace `<YOUR_FLUENTBIT_ROLE_ARN>` and `<YOUR_NAME_PREFIX>` with the values from your Terraform outputs.
2. Install the AWS logging daemonset via Helm:
```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-for-fluent-bit eks/aws-for-fluent-bit \
  --namespace observability \
  -f kubernetes/observability/fluent-bit-values.yaml
```

### 5.3 Cluster Autoscaler (Elastic Compute Scaling)
When your cluster reaches its maximum pod capacity, this automatically provisions new EC2 nodes.
1. Edit `kubernetes/observability/cluster-autoscaler-values.yaml`. Replace `<YOUR_AUTOSCALER_ROLE_ARN>` and `<YOUR_EKS_CLUSTER_NAME>` with the values from your Terraform outputs.
2. Install the Autoscaler via Helm:
```bash
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update
helm install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  -f kubernetes/observability/cluster-autoscaler-values.yaml
```

---

## 🚀 Step 6: Route Traffic (Ingress)
Since we just added Grafana, the Ingress file now handles routing for three separate components!
1. Open `kubernetes/ingress.yaml` on the Bastion Host.
2. Replace `<YOUR_ACM_CERTIFICATE_ARN>` with the actual ARN from the Terraform output.
3. Apply the ingress:
```bash
kubectl apply -f kubernetes/ingress.yaml
```

**Final DNS Step:**
Run `kubectl get ingress`. Copy the Load Balancer `ADDRESS` URL. Finally, go back to your Domain Registrar (Hostinger) and create a **CNAME** (or **ALIAS**) record pointing your root domain (`@`) and/or `www` to that Load Balancer URL.

## 🚀 Step 7: Deploying the Frontend UI
Upload your compiled frontend build (e.g., React/Vite `./dist` folder) to the UI S3 bucket. CloudFront will automatically serve it globally.
*(Run this from your local machine, not the Bastion)*:

```bash
cd environments/dev
aws s3 sync ../../frontend/dist s3://$(terraform output -raw ui_bucket_name) --delete
```