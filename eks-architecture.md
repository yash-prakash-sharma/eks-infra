# Production-Ready EKS Architecture

This document explains the architecture and operational flow of the provisioned Amazon EKS environment, designed specifically for a secure, scalable, and robust production setup.

## 1. Network Security: The Private Cluster
By default, EKS provisions a public endpoint for the Kubernetes API server (the control plane). For a production environment, this is a security risk.
We have configured the cluster to be **strictly private** (`endpoint_public_access = false`, `endpoint_private_access = true`).
- **Nodes:** EKS Worker nodes run exclusively in **Private Subnets**. They have no public IP addresses. They reach the internet to pull Docker images (ECR) via a **NAT Gateway** sitting in the Public Subnets.
- **Control Plane:** The EKS API Server endpoint is only accessible from within the VPC. 

## 2. Administration via Bastion Host
Because the EKS API is private, you cannot run `kubectl` commands from your local machine.
- We provisioned a **Bastion Host** (an EC2 instance in the public subnet).
- We added an explicit Security Group rule allowing the **Bastion Host** to communicate with the **EKS API Server** on TCP port 443.
- **Workflow:** To interact with the cluster, you must SSH into the Bastion Host. From there, you run `aws eks update-kubeconfig` and execute `kubectl` commands. The Bastion acts as your secure jump-box.

## 3. Storage & S3 Integration
The `file-service` requires access to an AWS S3 bucket to upload and stream files.
- **Bucket Provisioning:** A dedicated, private S3 bucket (`myapp-ue1-dev-eks-app-files`) is created using Terraform.
- **IAM Node Role:** Instead of hardcoding AWS Access/Secret keys within Kubernetes (which is an anti-pattern), we attached an IAM Policy directly to the EKS Node Group's IAM Role. 
- **Effect:** Any Pod running on these EKS nodes automatically inherits the permission to `s3:GetObject`, `s3:PutObject` on this specific bucket without needing explicit credentials. You can actually remove `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from your application config if your SDK supports default credential providers (like `boto3` or standard AWS SDKs).

## 4. Scalability 
The EKS Node Group is configured as a Managed Node Group.
- **Auto-Scaling:** Configured with `min_size=1`, `desired_size=2`, and `max_size=4`. If your pods require more compute resources than currently available, the Kubernetes Cluster Autoscaler (once installed) can automatically provision additional EC2 instances.
- **Deployments:** The `login-service` and `file-service` are configured as Kubernetes `Deployments` with `replicas: 2`, ensuring high availability across the nodes.

## 5. Deployment Process (End-to-End)

1. **Deploy Infrastructure:**
   Run Terraform from `environments/dev`:
   ```bash
   terraform apply -auto-approve -var-file="terraform-dev.tfvars"
   ```
2. **Access the Bastion:**
   SSH into the bastion host:
   ```bash
   ssh -i <your-key.pem> ec2-user@<BASTION_PUBLIC_IP>
   ```
3. **Configure the Cluster (From Bastion):**
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name myapp-ue1-dev-eks-app-eks-cluster
   ```
4. **Deploy Kubernetes Resources:**
   *Assuming you cloned the repo onto the bastion or copied your yaml files there.*
   - Review and apply `kubernetes/app-config.yaml` to create your ConfigMap and Secrets (Database URLs, S3 Bucket names).
   - Apply your application manifests:
     ```bash
     kubectl apply -f kubernetes/login-service.yaml
     kubectl apply -f kubernetes/file-service.yaml
     ```
5. **Verify:**
   ```bash
   kubectl get pods
   kubectl get svc
   ```
   Grab the `file-service` LoadBalancer URL to access your application.
