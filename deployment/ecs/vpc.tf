resource "aws_vpc" "main" {
  cidr_block              = "10.0.0.0/16" # 65536 addresses available
  instance_tenancy        = "default" # execute multiple instances in the same physical server
  enable_dns_support      = true # this one and the next are required to have an internal DNS hostname and domain name
  enable_dns_hostnames    = true 
  tags = {
    Name = "Main VPC"
  }
}

# Public subnets: enable traffic to and from the internet
resource "aws_subnet" "main-public-1" {
  vpc_id                  = aws_vpc.main.id # reference to the VPC created above
  cidr_block              = "10.0.1.0/24" # 256 addresses available
  map_public_ip_on_launch = true # enable public IP for instances launched in this subnet to access the internet
  availability_zone       = "eu-west-1a"
  tags = {
    Name = "Main Public Subnet 1"
  }
}

resource "aws_subnet" "main-public-2" {
  vpc_id                  = aws_vpc.main.id # reference to the VPC created above
  cidr_block              = "10.0.2.0/24" # 256 addresses available
  map_public_ip_on_launch = true # enable public IP for instances launched in this subnet to access the internet
  availability_zone       = "eu-west-1b"
  tags = {
    Name = "Main Public Subnet 2"
  }
}

# Internet Gateway: this resource creates a gateway in the Main VPC required to connect the instances residing any public subnet to the internet
resource "aws_internet_gateway" "main-gateway" {
  vpc_id                  = aws_vpc.main.id # reference to the VPC created above
  tags = {
    Name = "Main Public Gateway"
  }
}

# Public Route Table: this resource creates a route table in the Main VPC required to route traffic from the instances residing any public subnet to the internet gateway
resource "aws_route_table" "main-public-route-table" {
  vpc_id                  = aws_vpc.main.id # reference to the VPC created above
  route {
    cidr_block            = "0.0.0.0/0" # route all traffic initiated from the instances in the public subnets to the internet gateway
    gateway_id            = aws_internet_gateway.main-gateway.id # reference to the internet gateway created above
  }
  tags = {
    Name = "Main Public Route Table"
  }
}

# Route Table Association: this resource associates the route table created above with the public subnets
resource "aws_route_table_association" "main-public-1-association" {
  subnet_id               = aws_subnet.main-public-1.id # reference to the first public subnet created above
  route_table_id          = aws_route_table.main-public-route-table.id # reference to the route table created above
}

resource "aws_route_table_association" "main-public-2-association" {
  subnet_id               = aws_subnet.main-public-2.id # reference to the first public subnet created above
  route_table_id          = aws_route_table.main-public-route-table.id # reference to the route table created above
}
