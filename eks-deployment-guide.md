# EKS Deployment Guide

This guide details the deployment process for `login-service` and `file-service` onto the EKS cluster, reflecting production-ready practices for scalability, security, and robustness.

## Architecture Context
- **EKS Cluster:** Provisioned via Terraform in private subnets, ensuring nodes aren't publicly accessible.
- **NAT Gateway:** Enables nodes to pull images from ECR.
- **RDS MySQL:** Running in private subnets. EKS nodes will communicate with RDS over the VPC internal network.

## 1. Apply Terraform Configuration
Run Terraform to provision the EKS cluster and updated networking.
```bash
cd environments/dev
terraform apply -auto-approve -var-file="terraform-dev.tfvars"
```

## 2. Connect `kubectl` to your EKS Cluster
Once Terraform applies successfully, grab the `eks_cluster_name` from the output and update your `kubeconfig`:
```bash
aws eks update-kubeconfig --region us-east-1 --name <YOUR_CLUSTER_NAME>
```
Verify connectivity:
```bash
kubectl get nodes
```

## 3. Configure Secrets Securely
**Production Best Practice:** Never hardcode secrets in YAML files tracked by Git. 
We've provided `kubernetes/app-config.yaml` as an example.

### Option A: AWS Secrets Manager & External Secrets Operator (Recommended for Prod)
1. Store credentials (DB passwords, AWS Access Keys, Secret Keys) in **AWS Secrets Manager**.
2. Install the **External Secrets Operator** in your EKS cluster.
3. Configure `ExternalSecret` custom resources to fetch these secrets natively into standard Kubernetes `Secret` objects dynamically.

### Option B: Manual Base64 Secrets (For Setup/Dev)
If not using an operator, manually encode your secrets and deploy them:
1. Encode your secrets: `echo -n 'your_secret_value' | base64`
2. Update `kubernetes/app-config.yaml` with the `Base64` values in the `app-secrets` block.
3. Update the `app-config` ConfigMap with your actual RDS Endpoint, Region, Bucket names, etc.
4. Apply to cluster:
   ```bash
   kubectl apply -f kubernetes/app-config.yaml
   ```

## 4. Deploy the Services
The manifests (`login-service.yaml` and `file-service.yaml`) define `Deployments` configured with 2 Replicas, representing a scalable foundation. They inject secrets securely through `env: valueFrom` directives.

1. Ensure your ECR image URIs are updated inside `login-service.yaml` and `file-service.yaml`.
2. Apply the Deployments and Services:
   ```bash
   kubectl apply -f kubernetes/login-service.yaml
   kubectl apply -f kubernetes/file-service.yaml
   ```

## 5. Expose traffic (Ingress/LoadBalancer)
- The `login-service` is deployed as `ClusterIP` (internal communication only).
- The `file-service` is deployed as `LoadBalancer`, which dynamically creates an AWS Classic Load Balancer. 
*Production Note:* For a high-traffic production application, migrate this away from `type: LoadBalancer` and utilize an **AWS ALB Ingress Controller** to manage a single application load balancer routing based on paths (`/login`, `/files`).

To track the LoadBalancer IP for `file-service`:
```bash
kubectl get svc
```
It may take 2-3 minutes for the AWS Load Balancer to provision.

## Phase 3: Custom Domain & Ingress (ALB Controller)
For a production-ready setup, we route traffic using a single Application Load Balancer via the **AWS Load Balancer Controller**.

1. Set your Hostinger domain in `environments/dev/terraform-dev.tfvars`:
   ```hcl
   domain_name = "yourdomain.com"
   ```
2. Run `terraform apply` locally.
3. The apply will output `domain_validation_options`. You must go to your Hostinger Domain Dashboard and add these **CNAME** records. This proves to AWS that you own the domain so it can issue the SSL certificate.
4. From your **Bastion Host**, you need to install the AWS Load Balancer Controller using Helm. Copy the `alb_controller_role_arn` and `eks_cluster_name` from your Terraform outputs and run:
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
5. Still on your Bastion Host, apply the Ingress manifest, making sure to replace `<YOUR_ACM_CERTIFICATE_ARN>` inside `kubernetes/ingress.yaml` with the actual ACM Certificate ARN from your Terraform output:
   ```bash
   kubectl apply -f kubernetes/ingress.yaml
   ```
5. Check the ALB creation:
   ```bash
   kubectl get ingress app-ingress
   ```
6. The `kubectl get ingress` output will eventually show an AWS Load Balancer URL under the "ADDRESS" column. Finally, in your Hostinger Dashboard, create a **CNAME** record for your root domain (or `www`) pointing to this Application Load Balancer URL.
