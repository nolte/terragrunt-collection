# https://www.vaultproject.io/docs/auth/kubernetes

data "kubernetes_namespace" "this" {
  metadata {
    name = "vault"
  }
}

resource "kubernetes_service_account" "this" {
  metadata {
    name = "vault-login-sa"
    namespace = data.kubernetes_namespace.this.metadata.0.name
  }
  secret {
    name = kubernetes_secret.this.metadata.0.name
  }
}

data "kubernetes_secret" "this" {
  depends_on = [ kubernetes_service_account.this ]
  metadata {
    name = kubernetes_service_account.this.default_secret_name
    namespace = data.kubernetes_namespace.this.metadata.0.name
  }
}

resource "kubernetes_secret" "this" {
  metadata {
    name = "vault-login-sa"
    namespace = data.kubernetes_namespace.this.metadata.0.name
  }
}


resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "example" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = "https://kubernetes.svc:443"
  kubernetes_ca_cert     = data.kubernetes_secret.this.data["ca.crt"]
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


resource "vault_kubernetes_auth_backend_role" "example" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "demo"
  bound_service_account_names      = [kubernetes_service_account.vault_auth.metadata.0.name]
  bound_service_account_namespaces = [kubernetes_service_account.vault_auth.metadata.0.namespace]
  token_ttl                        = 3600
  token_policies                   = ["default"]
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
  path = format("%s/foo",module.secrets_engine.path)

  data_json = <<EOT
{
  "foo":   "bar",
  "pizza": "cheese"
}
EOT
}