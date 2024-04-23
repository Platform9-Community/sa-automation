provider "aws" { 
  region = "us-east-1"
}

# Create IAM user
resource "aws_iam_user" "emp-auto-test" {
  name = var.empuser
}

resource "aws_iam_access_key" "empuser_access_key" {
  user = aws_iam_user.emp-auto-test.name
}

# Give Permissions to the user
resource "aws_iam_policy" "custom_policy" {
  name = "emp-validation-user-policy"
  policy = file("iam_policy.json")
}

resource "aws_iam_policy_attachment" "custom_policy_attachment" {
  name = "emp-validation-user-policy-attachment"
  policy_arn = aws_iam_policy.custom_policy.arn
  users = var.empuser
}
