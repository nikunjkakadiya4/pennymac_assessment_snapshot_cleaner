# Looks up AZ names so private subnets can be spread across two zones for HA of ENIs and interface endpoints.
data "aws_availability_zones" "available" {
  state = "available"
}

# Dedicated VPC for the snapshot cleaner; DNS options allow private hosted zone / endpoint DNS resolution.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# First private subnet: no direct internet route; hosts Lambda ENIs and VPC endpoint interfaces in AZ 0.
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[0]
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-private-a"
  }
}

# Second private subnet in another AZ for redundancy of Lambda and interface endpoints.
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[1]
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.project_name}-private-b"
  }
}

# Route table for private subnets (no IGW routes); associations below attach subnets to this table.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Associates private subnet A with the private route table so it uses VPC-internal routing only.
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

# Associates private subnet B with the same private route table.
resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# Security group for interface VPC endpoints: allows HTTPS from anywhere in the VPC CIDR to reach AWS APIs privately.
resource "aws_security_group" "vpc_endpoint" {
  name        = "${var.project_name}-vpce-aws-api"
  description = "Allow HTTPS from workloads in the VPC to interface VPC endpoints (EC2, Logs)"
  vpc_id      = aws_vpc.main.id

  # Permit TLS from any resource in this VPC (including Lambda ENIs) to the endpoint network interfaces.
  ingress {
    description = "HTTPS from workloads in the VPC (e.g. Lambda ENIs)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # Standard egress for the endpoint SG (AWS control plane traffic as required by the endpoint service).
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-vpce-sg"
  }
}

# Interface endpoint for EC2 API so Lambda in private subnets can Describe/Delete snapshots without a NAT gateway.
resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-ec2-endpoint"
  }
}

# Interface endpoint for CloudWatch Logs so Lambda can ship logs while remaining on private networking only.
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-logs-endpoint"
  }
}

# Security group for the Lambda ENIs: outbound HTTPS only within the VPC toward interface endpoints.
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda"
  description = "Egress for Lambda to reach EC2 and CloudWatch Logs via VPC endpoints"
  vpc_id      = aws_vpc.main.id

  # Lambda reaches EC2/Logs private DNS targets (in-VPC) over TLS on 443.
  egress {
    description = "HTTPS to interface endpoints and other VPC-private services"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name = "${var.project_name}-lambda-sg"
  }
}
