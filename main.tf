provider "aws" {
  access_key                  = "mock_access_key"
  secret_access_key            = "mock_secret_key"
  region                        = "us-east-1"
  s3_force_path_style           = true
  skip_credentials_validation  = true
  skip_requesting_account_id   = true
  skip_metadata_api_check      = true
  endpoints {
    s3 = "http://localhost:4566"
    lambda = "http://localhost:4566"
  }
}

resource "aws_s3_bucket" "source_bucket" {
  bucket = "s3-start"
}

resource "aws_s3_bucket" "destination_bucket" {
  bucket = "s3-finish"
}

resource "aws_s3_bucket_lifecycle_configuration" "source_lifecycle" {
  bucket = aws_s3_bucket.source_bucket.id

  rule {
    id     = "expire-objects"
    status = "Enabled"

    expiration {
      days = 7
    }
  }
}

resource "aws_lambda_function" "s3_copy_function" {
  function_name = "s3-copy-function"
  handler       = "MyLambdaFunction::MyLambdaFunction.Function::FunctionHandler"
  runtime       = "dotnetcore3.1"
  role          = aws_iam_role.iam_for_lambda.arn
  filename      = "${path.module}/function.zip"
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_copy_function.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.source_bucket.arn
}

resource "aws_s3_bucket_notification" "source_notification" {
  bucket = aws_s3_bucket.source_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_copy_function.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"
  
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

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  role = aws_iam_role.iam_for_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.source_bucket.arn,
          "${aws_s3_bucket.source_bucket.arn}/*",
          aws_s3_bucket.destination_bucket.arn,
          "${aws_s3_bucket.destination_bucket.arn}/*"
        ]
      }
    ]
  })
}
