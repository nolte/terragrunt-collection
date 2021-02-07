remote_state {
  backend = "s3"
  generate = {
    path      = "backend.gen.tf"
    if_exists = "overwrite"
  }  
  config = {
    bucket = "tf-states"
    endpoint = "http://devops-tools-argocd-minio.minio.svc"
    region = "main"
    key    = "basement/${path_relative_to_include()}/terraform.tfstate"
    skip_credentials_validation = true
    skip_metadata_api_check = true
    skip_region_validation = true
    force_path_style = true
  }
}

generate "versions" {
  path      = "versions_override.gen.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    minio = {
      source = "aminueza/minio"
      version = "1.2.0"
    }
  }
}
EOF
}