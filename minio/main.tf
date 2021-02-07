resource "minio_s3_bucket" "workflow_storage" {
  bucket = "workflow-storage"
  acl   = "public-read-write"
}

data "minio_iam_policy_document" "example" {
  statement {
    sid = "1"
    actions = [
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation",
    ]
    effect = "Allow"
    resources = [
      "arn:aws:s3:::*",
    ]
  }

  statement {
    actions = [
      "s3:ListBucket",
    ]
    effect = "Allow"
    resources = [
      "arn:aws:s3:::${minio_s3_bucket.workflow_storage.bucket}",
    ]
  }

  statement {
    actions = [
      "s3:PutObject",
    ]
    effect = "Allow"
    resources = [
      "arn:aws:s3:::${minio_s3_bucket.workflow_storage.bucket}",
      "arn:aws:s3:::${minio_s3_bucket.workflow_storage.bucket}/*",
    ]
  }
}

resource "minio_iam_user" "workflow_user" {
  name = "workflow-user"
}
output "workflow_user" {
  value = minio_iam_user.workflow_user
}

resource "minio_iam_policy" "workflow_storage" {
  name = "workflow-storage"
  policy    = data.minio_iam_policy_document.example.json
}
resource "minio_iam_user_policy_attachment" "workflow_user" {
  user_name      = "${minio_iam_user.workflow_user.id}"
  policy_name = "${minio_iam_policy.workflow_storage.id}"
}


#resource "minio_iam_group_policy" "workflow_storage" {
#  name = "workflow-storage"
#  group = "${minio_iam_group.workflow_users.id}"
#  policy    = data.minio_iam_policy_document.example.json
#}
#
#resource "minio_iam_group" "workflow_users" {
#  name = "workflows"
#}
#
#
#
#resource "minio_iam_group_membership" "workflow_users" {
#    name = "workflow-group-membership"
#
#  users = [
#    minio_iam_user.workflow_user.name,
#  ]
#
#  group = minio_iam_group.workflow_users.name
#}