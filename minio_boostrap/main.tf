variable "secrets_engine" {
  default = "secrets"
}

resource "vault_generic_secret" "example" {
  path = format("%s/foo",var.secrets_engine.path)

  data_json = <<EOT
{
  "foo":   "bar",
  "pizza": "cheese"
}
EOT
}