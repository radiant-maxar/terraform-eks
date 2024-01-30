## cert-manager
locals {
  cert_manager_policy = var.cert_manager && length(var.cert_manager_route53_zone_ids) > 0
  # The best practices values and defaults are sourced from:
  # https://cert-manager.io/docs/installation/best-practice/
  cert_manager_best_practice_defaults = merge(var.cert_manager_best_practice_defaults, {
    automountServiceAccountToken = false
    serviceAccount = {
      automountServiceAccountToken = false
    }
    # https://cert-manager.io/docs/installation/best-practice/#restrict-auto-mount-of-service-account-tokens
    volumes = [
      {
        name = "serviceaccount-token"
        projected = {
          defaultMode = 292 # int(0o444)
          sources = [
            {
              serviceAccountToken = {
                expirationSeconds = 3607
                path              = "token"
              }
            },
            {
              configMap = {
                name = "kube-root-ca.crt"
                items = [
                  {
                    key  = "ca.crt"
                    path = "ca.crt"
                  },
                ]
              }
            },
            {
              downwardAPI = {
                items = [
                  {
                    path = "namespace"
                    fieldRef = {
                      apiVersion = "v1"
                      fieldPath  = "metadata.namespace"
                    }
                  }
                ]
              }
            },
          ]
        }
      }
    ]
    volumeMounts = [
      {
        mountPath = "/var/run/secrets/kubernetes.io/serviceaccount"
        name      = "serviceaccount-token"
        readOnly  = true
      },
    ]
  })
  cert_manager_best_practice_values = merge(local.cert_manager_best_practice_defaults, {
    cainjector = merge(local.cert_manager_best_practice_defaults, {
      # This best practice is disabled because other common components,
      # like Cluster API's resource manager, depend on the cainjector
      # being available to all namespaces.  See:
      # https://cert-manager.io/docs/installation/best-practice/#memory
      # extraArgs = [
      #   "--namespace=${var.cert_manager_namespace}",
      #   "--enable-certificates-data-source=false",
      # ]
      podDisruptionBudget = local.cert_manager_pdb
      replicaCount        = 2
    })
    podDisruptionBudget = local.cert_manager_pdb
    replicaCount        = 2
    startupapicheck     = local.cert_manager_best_practice_defaults
    webhook = merge(local.cert_manager_best_practice_defaults, {
      replicaCount        = 3
      podDisruptionBudget = local.cert_manager_pdb
    })
  })
  # https://cert-manager.io/docs/installation/best-practice/#poddisruptionbudget
  cert_manager_pdb = {
    enabled      = true
    minAvailable = 1
  }
}

module "cert_manager_irsa" {
  count   = var.cert_manager ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.33.1"

  role_name = "${var.cluster_name}-cert-manager-role"

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "${var.cert_manager_namespace}:cert-manager",
      ]
    }
  }
  tags = var.tags
}

data "aws_iam_policy_document" "cert_manager" {
  count = local.cert_manager_policy ? 1 : 0
  statement {
    actions = [
      "route53:GetChange"
    ]
    resources = ["arn:${local.aws_partition}:route53:::change/*"]
  }

  statement {
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
    ]
    resources = [
      for zone_id in var.cert_manager_route53_zone_ids : "arn:${local.aws_partition}:route53:::hostedzone/${zone_id}"
    ]
  }
}

resource "aws_iam_policy" "cert_manager" {
  count       = local.cert_manager_policy ? 1 : 0
  name        = "AmazonEKS_Cert_Manager_Policy-${var.cluster_name}"
  description = "Provides permissions for cert-manager"
  policy      = data.aws_iam_policy_document.cert_manager[0].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "cert_manager" {
  count      = local.cert_manager_policy ? 1 : 0
  role       = module.cert_manager_irsa[0].iam_role_name
  policy_arn = aws_iam_policy.cert_manager[0].arn
  depends_on = [
    module.cert_manager_irsa[0]
  ]
}

resource "helm_release" "cert_manager" {
  count            = var.cert_manager ? 1 : 0
  name             = "cert-manager"
  namespace        = var.cert_manager_namespace
  create_namespace = var.cert_manager_namespace == "kube-system" ? false : true
  chart            = "cert-manager"
  repository       = "https://charts.jetstack.io"
  version          = "v${var.cert_manager_version}"
  wait             = var.cert_manager_wait
  keyring          = "${path.module}/cert-manager-keyring.gpg"
  verify           = var.helm_verify

  # Set up values so CRDs are installed with the chart, the service account has
  # correct annotations, and that the pod's security context has permissions
  # to read the account token:
  # https://cert-manager.io/docs/configuration/acme/dns01/route53/#service-annotation
  values = concat(
    [
      yamlencode({
        installCRDs = true
        securityContext = {
          fsGroup = 1001
        }
        serviceAccount = {
          annotations = {
            "eks.amazonaws.com/role-arn" = module.cert_manager_irsa[0].iam_role_arn
          }
        }
      }),
      yamlencode(var.cert_manager_values),
    ],
    var.cert_manager_best_practice ? [yamlencode(local.cert_manager_best_practice_values)] : [],
  )

  depends_on = [
    module.cert_manager_irsa[0],
    module.eks,
  ]
}
