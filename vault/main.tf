# https://www.vaultproject.io/docs/auth/kubernetes

data "kubernetes_namespace" "this" {
  metadata {
    name = "vault"
  }
}

data "kubernetes_service_account" "this" {
  metadata {
    name = "vault"
    namespace = data.kubernetes_namespace.this.metadata.0.name
  }
}

data "kubernetes_secret" "this" {
  metadata {
    name = data.kubernetes_service_account.this.default_secret_name
    namespace = data.kubernetes_namespace.this.metadata.0.name
  }
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "example" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = "https://kubernetes.svc:443"
  kubernetes_ca_cert     = <<EOF
-----BEGIN CERTIFICATE-----
MIIC5zCCAc+gAwIBAgIBADANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQDEwprdWJl
cm5ldGVzMB4XDTIxMDIxNDEyNDU1NVoXDTMxMDIxMjEyNDU1NVowFTETMBEGA1UE
AxMKa3ViZXJuZXRlczCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMwH
tYwmGheYxL3tCzNXn0SvuXZYUm5r7xl9as3m2FNX6FIJImKU3L36TpDO6W+P8OF2
6nWPj1yBCqJZq/ltbEfsWagABP0zqrykHRDAkyftzR0Pb7hcVbH6Hon3l+8MRmLa
Pvu3xGD+cH9M/8gcLIUe4zHGrMYW97LADGn7Bs8cKfJgkxVJxvPgYBJ2aDSeNLO0
Dk34R3sW2kYMK4cJtgOHIFT3qiLr7+Y81GcYnoU582Yimy/bO8YlHCzVrdxBD3rF
8aUiYuXfo/NBg4Q6gHDw7l60pEwDzOCL59o9JjSVjsWEmYlD+2Ap+LKZ3NLZGc+9
AlKqwVPLHM06+8BWL70CAwEAAaNCMEAwDgYDVR0PAQH/BAQDAgKkMA8GA1UdEwEB
/wQFMAMBAf8wHQYDVR0OBBYEFBoTclYbd3Ppy3aekulCIoGnN21KMA0GCSqGSIb3
DQEBCwUAA4IBAQB/EYqyHPDWhpulIDGVqKB1uLeCq95uvMyXk939qDVwziXheXgv
Ahbfes2gX18Ma5E+KdB+kDgWCpMOzQKfDYSPXupxOpYKt1M9AJumgYeJzTwtSGB5
x0AjcMd5Cbt57bXlOg5Hhr+3FKkzf5uVtWupSk8OJIxtxL4HANT08VjToTVYgxXg
j/Rey4Tozsnr/LYN5+NTHjT9OFXPNCfJbBrkeZhDGB+v/kqkeqZnlgPJQOwtqRMd
XiYyrC5JALKb0D11/We4bZ2/iV1I2TXlBEog/STH84MFIt19z2so30BGdcED5S8x
42FaJScbme6oMwwykt9UN3/4Lnpy2JVOY54L
-----END CERTIFICATE-----
EOF
  token_reviewer_jwt     = data.kubernetes_secret.this.data.token
  issuer                 = "api"
  disable_iss_validation = "true"
}

resource "kubernetes_service_account" "vault_auth" {
  metadata {
    name = "vault-auth"
    namespace = "default"
  }
}

resource "vault_policy" "example" {
  name = "dev-team"

  policy = <<EOT
path "secrets/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOT
}


resource "vault_kubernetes_auth_backend_role" "example" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "demo"
  bound_service_account_names      = [kubernetes_service_account.vault_auth.metadata.0.name]
  bound_service_account_namespaces = [kubernetes_service_account.vault_auth.metadata.0.namespace]
  token_ttl                        = 3600
  token_policies                   = ["default","dev-team"]
  #audience                         = "vault"
}



resource "kubernetes_cluster_role_binding" "this" {
  metadata {
    name = "role-tokenreview-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.vault_auth.metadata.0.name
    namespace = kubernetes_service_account.vault_auth.metadata.0.namespace
  }
}

module "secrets_engine" {
  source = "github.com/nolte/terraform-vault-secrets-engine.git?ref=9eb551ee001924de184a35a385fcc7a7973dce41"

  path = "secrets"
  type = "kv"
  options = {
    version = 2
  }
}


resource "vault_generic_secret" "example" {
  path = format("%s/test/foo",module.secrets_engine.path)

  data_json = <<EOT
{
  "foo":   "bar",
  "pizza": "cheese"
}
EOT
}