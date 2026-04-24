# ID of the VPC created by aws_vpc.main (for peering, tagging, or parent stack outputs).
output "vpc_id" {
  value = aws_vpc.main.id
}

# Both private subnet resource IDs in order [private_a, private_b] for Lambda vpc_config.
output "private_subnet_ids" {
  value = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

# Security group to attach to Lambda so its ENIs use the intended egress rules.
output "lambda_security_group_id" {
  value = aws_security_group.lambda.id
}
