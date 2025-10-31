
terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

# Configure AWS provider
provider "aws" {
  region     = "eu-central-1"
}

# === 1. Create S3 bucket ===
resource "aws_s3_bucket" "practice_bucket" {
  bucket = "john77-practice-v2"
  force_destroy = true
}

# === 2. Add a bucket policy: allow only the root user ===
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "root_only" {
  bucket = aws_s3_bucket.practice_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowCurrentUserOnly"
        Effect   = "Allow"
        Principal = {
             AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = ["s3:*"]
        Resource = [
          aws_s3_bucket.practice_bucket.arn,
          "${aws_s3_bucket.practice_bucket.arn}/*"
        ]
      }
    ]
  })
  depends_on = [aws_s3_bucket.practice_bucket]
}

# === 3. Create an IAM Role for the Lambda function ===
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_s3_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach managed policies for logging and S3 access
resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_s3_access" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# === 4. Package the Lambda function ===
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/lambda_function.py"
  output_path = "${path.module}/lambda/lambda_function.zip"
}

# === 5. Create the Lambda function ===
resource "aws_lambda_function" "myPractice_v2" {
  function_name = "myPractice-v2"
  role          = aws_iam_role.lambda_exec_role.arn
  runtime       = "python3.9"
  handler       = "lambda_function.lambda_handler"
  filename      = data.archive_file.lambda_zip.output_path
  timeout       = 30
}

# === 6. Allow S3 to invoke the Lambda ===
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.myPractice_v2.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.practice_bucket.arn
}

# === 7. Create the S3 -> Lambda trigger for PUT events ===
resource "aws_s3_bucket_notification" "lambda_trigger" {
  bucket = aws_s3_bucket.practice_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.myPractice_v2.arn
    events              = ["s3:ObjectCreated:Put"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# === Output the bucket name for easy access ===
output "bucket_name" {
  value = aws_s3_bucket.practice_bucket.bucket
}
