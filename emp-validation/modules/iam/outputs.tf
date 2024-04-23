
# Output IAM user access key ID
output "iam_access_key_id" {
  value = aws_iam_access_key.empuser_access_key.id
}

# Output IAM user secret access key
output "iam_secret_access_key" {
  value = aws_iam_access_key.empuser_access_key.secret
}