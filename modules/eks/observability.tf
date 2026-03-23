# ------------------------------------------------------------------------------
# Observability: Prometheus & Grafana
# ------------------------------------------------------------------------------
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "observability"
  create_namespace = true
  wait             = false

  depends_on = [helm_release.aws_lbc]

  values = [
    <<-EOT
    defaultRules:
      create: true
    alertmanager:
      enabled: false
    pushgateway:
      enabled: false

    grafana:
      enabled: true
      adminPassword: "${var.grafana_admin_password}"
      
      persistence:
        enabled: true
        type: pvc
        size: 2Gi
        
      grafana.ini:
        server:
          domain: '${var.domain_name}'
          root_url: 'https://${var.domain_name}/grafana/'
          serve_from_sub_path: true

      ingress:
        enabled: true
        ingressClassName: alb
        annotations:
          alb.ingress.kubernetes.io/certificate-arn: "${var.acm_certificate_arn}"
          alb.ingress.kubernetes.io/group.name: "my-app-shared-alb"
          alb.ingress.kubernetes.io/group.order: "10"
          alb.ingress.kubernetes.io/scheme: internet-facing
          alb.ingress.kubernetes.io/target-type: ip
          alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
          alb.ingress.kubernetes.io/ssl-redirect: '443'
          # Required for ACM Certificate Binding, the user can patch this manually or use a default cert
          alb.ingress.kubernetes.io/success-codes: "200"
          alb.ingress.kubernetes.io/healthcheck-path: "/grafana/api/health"
        hosts:
          - "${var.domain_name}"
        path: /grafana
        pathType: Prefix

    prometheus:
      enabled: true
      prometheusSpec:
        retention: 5d
        storageSpec:
          volumeClaimTemplate:
            spec:
              accessModes: ["ReadWriteOnce"]
              resources:
                requests:
                  storage: 10Gi
    EOT
  ]
}

# ------------------------------------------------------------------------------
# Observability: Fluent Bit (Using EKS Pod Identity)
# ------------------------------------------------------------------------------

# 1. IAM Policy for CloudWatch Logging
data "aws_iam_policy_document" "fluentbit_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "fluentbit_policy" {
  name        = "${var.name_prefix}-fluentbit-policy"
  description = "Policy allowing Fluent Bit to push logs to CloudWatch"
  policy      = data.aws_iam_policy_document.fluentbit_policy.json
}

# 2. IAM Role (Assumable via pods.eks.amazonaws.com for Pod Identity)
data "aws_iam_policy_document" "fluentbit_assume_role" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fluentbit_role" {
  name               = "${var.name_prefix}-fluentbit-role"
  assume_role_policy = data.aws_iam_policy_document.fluentbit_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "fluentbit_policy_attach" {
  role       = aws_iam_role.fluentbit_role.name
  policy_arn = aws_iam_policy.fluentbit_policy.arn
}

# 3. EKS Pod Identity Association
resource "aws_eks_pod_identity_association" "fluentbit" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "observability"
  service_account = "fluent-bit"
  role_arn        = aws_iam_role.fluentbit_role.arn
}

# 4. Helm Release for Fluent Bit
resource "helm_release" "aws_for_fluent_bit" {
  name             = "aws-for-fluent-bit"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-for-fluent-bit"
  namespace        = "observability"
  create_namespace = true

  # Ensure the POD Identity association exists first before the pods spin up
  depends_on = [aws_eks_pod_identity_association.fluentbit]

  values = [
    <<-EOT
    global:
      hostNetwork: true
      
    serviceAccount:
      create: true
      name: fluent-bit
      # No IRSA annotations needed; we're using Pod Identity

    cloudWatchLogs:
      enabled: true
      region: ${data.aws_region.current.name}
      logGroupName: "/eks/${var.name_prefix}/containers"
      logStreamPrefix: "fluent-bit-"
      logFormat: "json/emf"
      logKey: "log"

    firehose:
      enabled: false
    kinesis:
      enabled: false
    elasticsearch:
      enabled: false
    opensearch:
      enabled: false

    config:
      inputs: |
        [INPUT]
            Name              tail
            Tag               kube.*
            Path              /var/log/containers/*_default_*.log
            Parser            docker
            DB                /var/fluent-bit/state/flb_kube.db
            Mem_Buf_Limit     5MB
            Skip_Long_Lines   On
            Refresh_Interval  10

      filters: |
        [FILTER]
            Name                kubernetes
            Match               kube.*
            Kube_URL            https://kubernetes.default.svc:443
            Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
            Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
            Kube_Tag_Prefix     kube.var.log.containers.
            Merge_Log           On
            Merge_Log_Key       log_processed
            Keep_Log            Off
            K8S-Logging.Parser  On
            K8S-Logging.Exclude Off
    EOT
  ]
}
