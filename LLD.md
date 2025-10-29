# Low Level Design (LLD) - UK MSVX CPS Infrastructure

## 1. Document Overview

### 1.1 Purpose
This document provides the detailed technical design for the UK MSVX CPS (Chief Security Officer Shared Services Portal) infrastructure deployment on AWS using Terraform modular architecture.

### 1.2 Scope
- Detailed component specifications
- Network architecture and security groups
- Service configurations and dependencies
- Database design and storage architecture
- Deployment automation and orchestration

### 1.3 Architecture Summary
```
┌─────────────────────────────────────────────────────────────────┐
│                    Internet Gateway                              │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────┴───────────────────────────────────────────┐
│           Application Load Balancer (HA Only)                   │
│         SSL Termination & Cognito Authentication               │
└─────────────┬───────────────────────┬─────────────────────────┘
              │                       │
    ┌─────────┴─────────┐   ┌─────────┴─────────┐
    │   Public Subnet   │   │   Public Subnet   │
    │    eu-west-2a     │   │    eu-west-2c     │
    │   NAT Gateway     │   │   NAT Gateway     │
    └─────────┬─────────┘   └─────────┬─────────┘
              │                       │
    ┌─────────┴─────────┐   ┌─────────┴─────────┐
    │  Private Subnet   │   │  Private Subnet   │
    │    eu-west-2a     │   │    eu-west-2c     │
    │                   │   │                   │
    │ Frontend (8102)   │   │ Frontend (8102)   │
    │ Backend (8080)    │   │ Backend (8080)    │
    │ Keystone (5000)   │   │ Keystone (5000)   │
    │ RabbitMQ (5672)   │   │ RabbitMQ (5672)   │
    │ Jump Server       │   │                   │
    └─────────┬─────────┘   └─────────┬─────────┘
              │                       │
    ┌─────────┴─────────────────────────┴─────────┐
    │              RDS MySQL Multi-AZ              │
    │           Performance Insights               │
    └─────────────────────────────────────────────┘
```

## 2. Infrastructure Components

### 2.1 Terraform Module Architecture

#### 2.1.1 Module Structure
```
modules/
├── networking/          # VPC, subnets, ALB, security groups
├── security/           # IAM roles, SSL certificates, KMS
├── compute/            # EC2 instances, user data, target groups
├── storage/            # EFS, S3 buckets, access points
├── database/           # RDS MySQL, subnet groups, monitoring
└── dns/                # Route53 private zones, health checks
```

#### 2.1.2 Environment Configuration
```yaml
# env.prod-ha.yaml
prod: true
ha: true
vpc_name: CSO-prod-ha
vpc_cidr: 10.1.0.0/16
jump_server_access_cidrs:
  - 10.0.0.0/8
  - 172.16.0.0/12
  - 192.168.0.0/16
admin_email: "admin@company.com"
```

### 2.2 Networking Module

#### 2.2.1 VPC Configuration
```hcl
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name        = "${var.environment}-${var.vpc_name}"
    Environment = var.environment
  }
}
```

**Specifications:**
- **CIDR Blocks**: 
  - Development: 10.0.0.0/24 (256 IPs)
  - Staging/Production: 10.x.0.0/16 (65,536 IPs)
- **DNS Resolution**: Enabled for service discovery
- **Region**: eu-west-2 (London)

#### 2.2.2 Subnet Design
```hcl
# Public Subnets (ALB, NAT Gateways)
public_cidrs = cidrsubnets(cidrsubnet(vpc_cidr,1,0), 1, 1)

# Private Subnets (Application Servers)
private_cidrs = cidrsubnets(cidrsubnet(vpc_cidr,1,1), 1, 1)
```

**Subnet Allocation:**
- **Public Subnets**: 
  - eu-west-2a: First half of upper CIDR
  - eu-west-2c: Second half of upper CIDR
- **Private Subnets**:
  - eu-west-2a: First half of lower CIDR  
  - eu-west-2c: Second half of lower CIDR

#### 2.2.3 Application Load Balancer (HA Only)
```hcl
resource "aws_lb" "frontend" {
  count              = var.ha ? 1 : 0
  name               = "${var.environment}-frontend-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.frontend_lb[count.index].id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]
}
```

**Load Balancer Specifications:**
- **Type**: Application Load Balancer (Layer 7)
- **Scheme**: Internet-facing
- **SSL Policy**: ELBSecurityPolicy-TLS-1-2-2017-01
- **Health Checks**: HTTP/HTTPS with custom paths
- **Cross-Zone Load Balancing**: Enabled

#### 2.2.4 Target Groups
```hcl
# Frontend Target Group
resource "aws_lb_target_group" "frontend" {
  name     = "${var.environment}-frontend-tg"
  port     = 8102
  protocol = "HTTP"
  
  health_check {
    path                = "/ui/management/login/system"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

# Keystone Target Group
resource "aws_lb_target_group" "keystone" {
  name     = "${var.environment}-keystone-tg"
  port     = 5000
  protocol = "HTTPS"
  
  health_check {
    path                = "/api/idm/v3"
    matcher             = "200,300"
    timeout             = 10
  }
}
```

### 2.3 Security Module

#### 2.3.1 Security Groups
```hcl
# Core Servers Security Group
resource "aws_security_group" "core-servers-sg" {
  name_prefix = "${var.environment}-core-servers-"
  vpc_id      = var.vpc_id

  # Inter-server communication
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  # MySQL access
  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"
    self      = true
  }
}
```

**Security Group Matrix:**
| Service | Inbound Ports | Source | Purpose |
|---------|---------------|--------|---------|
| Frontend | 8102, 443, 80 | ALB SG | Web traffic |
| Backend | 8080-8105 | Core SG | API services |
| Keystone | 5000 | Core SG | Identity API |
| RabbitMQ | 5672, 15671 | Core SG | Messaging |
| Jump Server | 8081 | ALB SG | Admin interface |
| RDS MySQL | 3306 | Core SG | Database |

#### 2.3.2 IAM Roles and Policies
```hcl
resource "aws_iam_role" "ssm_role" {
  name = "${var.environment}-ec2-ssm-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Attached Policies
- AmazonSSMManagedInstanceCore
- AmazonSSMPatchAssociation  
- CloudWatchAgentServerPolicy
- Custom S3 and Secrets Manager access
```

#### 2.3.3 SSL Certificate Management
```hcl
# Root CA Certificate
resource "tls_private_key" "root-ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "root-ca" {
  private_key_pem       = tls_private_key.root-ca.private_key_pem
  validity_period_hours = 30 * 365 * 24  # 30 years
  is_ca_certificate     = true
  
  subject {
    organization = "DXC"
    common_name  = "${var.environment} DXC SSP Root CA"
  }
}
```

### 2.4 Compute Module

#### 2.4.1 Instance Specifications

**Production Sizing:**
| Service | Instance Type | vCPU | Memory | Storage |
|---------|---------------|------|--------|---------|
| Frontend | c5.2xlarge | 8 | 16 GB | 50 GB GP3 |
| Backend | c5.4xlarge | 16 | 32 GB | 50 GB GP3 |
| Keystone | t2.xlarge | 4 | 16 GB | 50 GB GP3 |
| RabbitMQ | t2.xlarge | 4 | 16 GB | 50 GB GP3 |
| Jump Server | t2.large | 2 | 8 GB | 50 GB GP3 |

**Development Sizing:**
| Service | Instance Type | vCPU | Memory | Storage |
|---------|---------------|------|--------|---------|
| Frontend | t2.xlarge | 4 | 16 GB | 50 GB GP3 |
| Backend | t2.2xlarge | 8 | 32 GB | 50 GB GP3 |
| Keystone | t2.medium | 2 | 4 GB | 50 GB GP3 |
| RabbitMQ | t2.xlarge | 4 | 16 GB | 50 GB GP3 |
| Jump Server | t2.large | 2 | 8 GB | 50 GB GP3 |

#### 2.4.2 User Data and Initialization
```bash
#!/bin/bash
# Common initialization for all instances
dnf update -y
dnf install -y amazon-ssm-agent nfs-utils java-21-amazon-corretto

# Mount EFS filesystems
mkdir -p /opt/scripts /opt/ssl-certs
mount -t nfs4 -o nfsvers=4.1 ${efs_dns_name}:/ /opt/scripts
mount -t nfs4 -o nfsvers=4.1 ${ssl_certs_efs_dns_name}:/ /opt/ssl-certs

# Service-specific setup
/opt/scripts/unified-server-setup.sh ${environment} ${server_type} ${server_index}
```

#### 2.4.3 Service Dependencies
```
Jump Server (setup) → EFS Population → Service Servers
                                    ↓
Keystone Servers → Identity Service Ready → Frontend/Backend Servers
                                         ↓
                                    RabbitMQ Cluster
```

### 2.5 Storage Module

#### 2.5.1 EFS File Systems
```hcl
# Main Scripts EFS
resource "aws_efs_file_system" "efs" {
  creation_token   = "${var.environment}-efs"
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "provisioned"
  provisioned_throughput_in_mibps = 100
  
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
}

# SSL Certificates EFS
resource "aws_efs_file_system" "ssl_certs" {
  creation_token   = "${var.environment}-ssl-certs"
  encrypted        = true
  throughput_mode  = "provisioned"
  provisioned_throughput_in_mibps = 50
}
```

**EFS Specifications:**
- **Encryption**: KMS encryption at rest and in transit
- **Performance**: General Purpose with provisioned throughput
- **Lifecycle**: Transition to IA after 30 days
- **Mount Targets**: One per private subnet
- **Access Points**: POSIX permissions (uid:1000, gid:1000)

#### 2.5.2 S3 Bucket Configuration
```hcl
resource "aws_s3_bucket" "cso_files" {
  bucket = "${var.environment}-cso-files"
}

resource "aws_s3_bucket_encryption_configuration" "cso_files" {
  bucket = aws_s3_bucket.cso_files.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

### 2.6 Database Module

#### 2.6.1 RDS MySQL Configuration
```hcl
resource "aws_db_instance" "main" {
  identifier                   = "${var.environment}-db"
  instance_class               = var.prod ? "db.c5.4xlarge" : "db.t3.2xlarge"
  engine                       = "mysql"
  engine_version               = "8.0.42"
  allocated_storage            = 50
  max_allocated_storage        = 1000
  storage_encrypted            = true
  multi_az                     = var.ha
  backup_retention_period      = var.prod ? 30 : 7
  performance_insights_enabled = true
  monitoring_interval          = 60
}
```

**Database Specifications:**
- **Engine**: MySQL 8.0.42
- **Storage**: GP3 SSD with auto-scaling (50GB-1TB)
- **Backup**: Automated daily backups
- **Multi-AZ**: Enabled for HA deployments
- **Encryption**: KMS encryption at rest
- **Monitoring**: Performance Insights enabled

#### 2.6.2 Database Schema Design
```sql
-- Keystone Database
CREATE DATABASE keystone;
CREATE USER 'keystone'@'%' IDENTIFIED BY 'KeystonePass123';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%';

-- CSO Application Database  
CREATE DATABASE cso_portal;
CREATE USER 'cso_user'@'%' IDENTIFIED BY 'CSOPass123';
GRANT ALL PRIVILEGES ON cso_portal.* TO 'cso_user'@'%';
```

### 2.7 DNS Module

#### 2.7.1 Private Hosted Zone
```hcl
resource "aws_route53_zone" "private" {
  name = var.private_zone_name  # e.g., "dev-ha.cso.ss"
  
  vpc {
    vpc_id = var.vpc_id
  }
}
```

#### 2.7.2 DNS Records
```hcl
# Server A Records
resource "aws_route53_record" "server_records" {
  for_each = var.server_records
  
  zone_id = aws_route53_zone.private.zone_id
  name    = "${each.key}.${var.environment}.${var.domain_suffix}"
  type    = "A"
  ttl     = 300
  records = [each.value.ip]
}

# Service CNAME Records
resource "aws_route53_record" "service_aliases" {
  for_each = var.service_aliases
  
  zone_id = aws_route53_zone.private.zone_id
  name    = "${each.key}.${var.environment}.${var.domain_suffix}"
  type    = "CNAME"
  ttl     = 300
  records = ["${each.value}.${var.environment}.${var.domain_suffix}"]
}
```

**DNS Record Structure:**
```
# Server Records
frontend-server-1.dev-ha.cso.ss → 10.1.1.10
backend-server-1.dev-ha.cso.ss  → 10.1.1.20
keystone01.dev-ha.cso.ss        → 10.1.1.30
rabbitmq-server-1.dev-ha.cso.ss → 10.1.1.40

# Service Aliases
api.dev-ha.cso.ss      → backend-server-1.dev-ha.cso.ss
portal.dev-ha.cso.ss   → frontend-server-1.dev-ha.cso.ss
identity.dev-ha.cso.ss → keystone01.dev-ha.cso.ss
mq.dev-ha.cso.ss       → rabbitmq-server-1.dev-ha.cso.ss
```

## 3. Service-Level Design

### 3.1 Frontend Service Architecture

#### 3.1.1 Nginx Configuration
```nginx
server {
    listen 8102;
    server_name _;
    
    # Health check endpoint
    location /health {
        return 200 "OK";
        add_header Content-Type text/plain;
    }
    
    # CSO Management UI
    location /ui/management/ {
        proxy_pass http://localhost:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # Portal UI
    location /ui/portal/ {
        proxy_pass http://localhost:8202/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

#### 3.1.2 CSO Application Integration
- **Management UI Port**: 8102 (ALB target)
- **Portal UI Port**: 8202 (internal)
- **Backend Communication**: HTTP to backend services
- **Authentication**: Keystone token validation

### 3.2 Backend Service Architecture

#### 3.2.1 Service Port Allocation
```yaml
Services:
  - apidoc: 8098      # API Documentation
  - blobstore: 8091   # Binary Large Object Store
  - catalog: 8093     # Service Catalog
  - config: 8103      # Configuration Service
  - customers: 8090   # Customer Management
  - event: 8092       # Event Processing
  - export: 8105      # Data Export
  - fulfillment: 8097 # Order Fulfillment
  - pricing: 8100     # Pricing Engine
  - reporting: 8099   # Reporting Service
  - request: 8096     # Request Management
  - svcinst: 8094     # Service Instances
  - ticketing: 8101   # Ticketing System
```

#### 3.2.2 Backend Load Balancer (HA)
```hcl
resource "aws_lb" "backend_alb" {
  count              = local.env.ha ? 1 : 0
  name               = "${local.ws}-backend-alb"
  load_balancer_type = "application"
  internal           = true
  subnets            = [for subnet in module.networking.private_subnets : subnet.id]
}
```

### 3.3 Keystone Identity Service

#### 3.3.1 OpenStack Keystone Configuration
```python
# /etc/keystone/keystone.conf
[database]
connection = mysql+pymysql://keystone:KeystonePass123@mysql.dev-ha.cso.ss/keystone

[token]
provider = fernet
expiration = 3600

[fernet_tokens]
key_repository = /etc/keystone/fernet-keys

[DEFAULT]
transport_url = rabbit://ssp_user:RabbitPass123@mq.dev-ha.cso.ss:5672/ssp
```

#### 3.3.2 Apache WSGI Configuration
```apache
<VirtualHost *:5000>
    ServerName keystone01.dev-ha.cso.ss
    DocumentRoot /var/www/html
    
    WSGIDaemonProcess keystone python-path=/opt/keystone-venv/lib/python3.9/site-packages
    WSGIProcessGroup keystone
    WSGIScriptAlias / /usr/local/bin/keystone-wsgi-public
    
    SSLEngine on
    SSLCertificateFile /opt/ssl-certs/keystone01/server.crt
    SSLCertificateKeyFile /opt/ssl-certs/keystone01/server.key
    SSLCACertificateFile /opt/ssl-certs/ca/ca.crt
</VirtualHost>
```

#### 3.3.3 Keystone Clustering
```bash
# EFS-based fernet key synchronization
/etc/keystone/fernet-keys → /etc/keystone/fernet-keys-shared (EFS mount)

# Cluster health check
/opt/scripts/test-keystone-cluster.sh
# Expected: 2 servers, cross-server token validation working
```

### 3.4 RabbitMQ Message Broker

#### 3.4.1 RabbitMQ Configuration
```erlang
% /etc/rabbitmq/rabbitmq.conf
listeners.ssl.default = 5671
listeners.tcp.default = 5672

management.listener.port = 15671
management.listener.ssl = true

ssl_options.cacertfile = /opt/ssl-certs/ca/ca.crt
ssl_options.certfile   = /opt/ssl-certs/rabbitmq01/server.crt
ssl_options.keyfile    = /opt/ssl-certs/rabbitmq01/server.key

cluster_formation.peer_discovery_backend = classic_config
cluster_formation.classic_config.nodes.1 = rabbit@rabbitmq-server-1
cluster_formation.classic_config.nodes.2 = rabbit@rabbitmq-server-2
```

#### 3.4.2 RabbitMQ Clustering
```bash
# Shared Erlang cookie via EFS
/var/lib/rabbitmq/.erlang.cookie ← /opt/scripts/rabbitmq-cluster/erlang.cookie

# High Availability Policy
rabbitmqctl set_policy ha-all ".*" '{"ha-mode":"all"}' --priority 0 --apply-to queues

# Cluster status verification
rabbitmqctl cluster_status
# Expected: 2 nodes running, all queues mirrored
```

### 3.5 Jump Server Administration

#### 3.5.1 Admin Interface
```python
# Flask-based admin interface on port 8080
from flask import Flask, render_template, request
import requests

app = Flask(__name__)

@app.route('/admin/')
def admin_dashboard():
    # RabbitMQ status
    rabbitmq_status = check_rabbitmq_health()
    
    # Keystone status  
    keystone_status = check_keystone_health()
    
    return render_template('dashboard.html', 
                         rabbitmq=rabbitmq_status,
                         keystone=keystone_status)
```

#### 3.5.2 Service Management Scripts
```bash
# Service-specific setup scripts
/opt/scripts/unified-server-setup.sh    # Universal setup
/opt/scripts/keystone-setup.sh          # Keystone identity service
/opt/scripts/rabbitmq-setup.sh          # Message broker
/opt/scripts/frontend-setup.sh          # Web frontend
/opt/scripts/backend-setup.sh           # API backend

# Monitoring and health checks
/opt/scripts/test-keystone-cluster.sh   # Keystone cluster health
/opt/scripts/test-rabbitmq-cluster-health.sh  # RabbitMQ cluster health
```

## 4. Network Security Design

### 4.1 Security Group Rules

#### 4.1.1 Frontend Load Balancer Security Group
```hcl
# Inbound Rules
Port 80   (HTTP)  ← 0.0.0.0/0
Port 443  (HTTPS) ← 0.0.0.0/0  
Port 8102 (CSO)   ← 0.0.0.0/0

# Outbound Rules
All Traffic → 0.0.0.0/0
```

#### 4.1.2 Core Servers Security Group
```hcl
# Inbound Rules
All TCP Ports ← Self (inter-server communication)
Port 3306     ← Self (MySQL access)

# Outbound Rules  
All Traffic → 0.0.0.0/0
```

#### 4.1.3 EFS Security Group
```hcl
# Inbound Rules
Port 2049 (NFS) ← Core Servers SG
Port 2049 (NFS) ← Jump Server SG

# Outbound Rules
All Traffic → 0.0.0.0/0
```

### 4.2 Network Access Control Lists (NACLs)
```hcl
# Default VPC NACL allows all traffic
# Custom NACLs can be implemented for additional security layers
```

### 4.3 VPC Endpoints
```hcl
# SSM VPC Endpoints for private subnet access
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.eu-west-2.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for subnet in aws_subnet.private : subnet.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
}
```

## 5. Data Flow and Integration

### 5.1 Authentication Flow
```
1. User → ALB (HTTPS:443)
2. ALB → Cognito Authentication (HA only)
3. Cognito → ALB (OAuth2 callback)
4. ALB → Frontend Server (HTTP:8102)
5. Frontend → Keystone (HTTPS:5000) [Token validation]
6. Keystone → RDS MySQL [User verification]
7. Frontend → Backend Services [Authenticated requests]
```

### 5.2 Service Communication
```
Frontend (8102) ←→ Backend Services (8090-8105)
                ↓
            Keystone (5000) ←→ RDS MySQL (3306)
                ↓
            RabbitMQ (5672/5671) ←→ All Services
```

### 5.3 File and Configuration Management
```
S3 Bucket → Jump Server → EFS (/opt/scripts)
                       → EFS (/opt/ssl-certs)
                       ↓
                   All Servers (NFS mounts)
```

## 6. Monitoring and Logging

### 6.1 CloudWatch Integration
```hcl
# EC2 Instance Monitoring
monitoring = true

# RDS Performance Insights
performance_insights_enabled = true
monitoring_interval = 60

# Application Load Balancer Logging
access_logs {
  bucket  = aws_s3_bucket.alb_logs.bucket
  enabled = true
}
```

### 6.2 Log Aggregation
```bash
# Application Logs
/var/log/cso-setup.log              # Setup progress
/var/log/keystone-setup-progress.log # Keystone setup
/var/log/rabbitmq-setup-progress.log # RabbitMQ setup
/var/log/efs-s3-sync.log            # File synchronization

# System Logs
/var/log/cloud-init-output.log      # Instance initialization
/var/log/httpd/keystone.log         # Keystone service
/var/log/rabbitmq/                  # RabbitMQ cluster
```

### 6.3 Health Check Endpoints
```bash
# Service Health Checks
GET /health                         # Frontend health
GET /api/idm/v3                    # Keystone API health
GET /api/overview                  # RabbitMQ management
GET /admin/                        # Jump server admin interface
```

## 7. Backup and Recovery

### 7.1 RDS Backup Strategy
```hcl
backup_retention_period = var.prod ? 30 : 7
backup_window          = "03:00-04:00"
maintenance_window     = "sun:04:00-sun:05:00"
skip_final_snapshot    = !var.prod
```

### 7.2 EFS Backup
```hcl
# EFS Lifecycle Policy
lifecycle_policy {
  transition_to_ia = "AFTER_30_DAYS"
}

# EFS Backup (AWS Backup service integration)
tags = {
  Backup = "required"
}
```

### 7.3 Configuration Backup
```bash
# Terraform State Backup
Backend: S3 with versioning enabled
State Locking: DynamoDB table

# Application Configuration
EFS snapshots via AWS Backup
S3 versioning for installation packages
```

## 8. Deployment Automation

### 8.1 Terraform Deployment Process
```bash
# Environment Selection
terraform workspace select prod-ha

# Deployment Execution
./deploy.ps1 -AutoApprove

# Infrastructure Validation
terraform plan -detailed-exitcode
```

### 8.2 Service Orchestration
```bash
# Deployment Sequence
1. Infrastructure (Terraform) → 5-10 minutes
2. Jump Server Setup → 10-15 minutes  
3. Service Dependencies → 15-30 minutes
4. Application Installation → 30-60 minutes
5. Health Validation → 5-10 minutes

Total Deployment Time: 65-125 minutes
```

### 8.3 Rollback Procedures
```bash
# Infrastructure Rollback
terraform workspace select prod-ha
terraform destroy -auto-approve

# Service Rollback
terraform taint module.compute.aws_instance.frontend[0]
terraform apply -auto-approve

# Configuration Rollback
git revert <commit-hash>
./deploy.ps1
```

## 9. Capacity Planning and Management

### 9.1 AWS Compute Capacity Planning

#### 9.1.1 EC2 Instance Sizing Strategy
```yaml
Instance Family Selection:
  General Purpose (T3/T4g):
    - Burstable performance for variable workloads
    - Baseline CPU with burst credits
    - Cost-effective for development environments
    
  Compute Optimized (C5/C6i):
    - High-performance processors
    - Consistent CPU performance
    - Ideal for CPU-intensive applications
    
  Memory Optimized (R5/R6i):
    - High memory-to-vCPU ratios
    - For memory-intensive applications
    - Database caching and in-memory processing
```

#### 9.1.2 CPU Capacity Planning
```yaml
CPU Utilization Targets:
  Development: 40-60% average, 80% peak
  Staging:     50-70% average, 85% peak
  Production:  60-75% average, 90% peak

CPU Scaling Thresholds:
  Scale Out:  CPU > 75% for 5 minutes
  Scale In:   CPU < 25% for 10 minutes
  
Instance vCPU Allocation:
  Frontend:  4-8 vCPUs (c5.xlarge - c5.2xlarge)
  Backend:   8-16 vCPUs (c5.2xlarge - c5.4xlarge)
  Keystone:  2-4 vCPUs (t3.medium - t3.xlarge)
  RabbitMQ:  4-8 vCPUs (t3.xlarge - c5.2xlarge)
  Jump:      2-4 vCPUs (t3.medium - t3.large)
```

#### 9.1.3 Memory Capacity Planning
```yaml
Memory Utilization Targets:
  Application Heap: 60-75% of allocated memory
  System Memory:    70-85% utilization
  Buffer/Cache:     15-25% for OS operations

Memory Allocation by Service:
  Frontend Services:
    - Nginx:          512MB - 1GB
    - Java Heap:      2GB - 8GB
    - OS/System:      2GB - 4GB
    - Total Required: 8GB - 16GB
    
  Backend Services:
    - Java Heap:      4GB - 16GB
    - Connection Pool: 512MB - 2GB
    - OS/System:      4GB - 8GB
    - Total Required: 16GB - 32GB
    
  Keystone Service:
    - Python Process: 1GB - 4GB
    - Apache/WSGI:    512MB - 2GB
    - OS/System:      2GB - 4GB
    - Total Required: 4GB - 16GB
    
  RabbitMQ Cluster:
    - Erlang VM:      2GB - 8GB
    - Message Store:  2GB - 8GB
    - OS/System:      2GB - 4GB
    - Total Required: 8GB - 16GB
```

### 9.2 AWS Storage Capacity Planning

#### 9.2.1 EBS Volume Planning
```yaml
EBS Volume Types:
  gp3 (General Purpose SSD):
    - Baseline: 3,000 IOPS, 125 MiB/s
    - Scalable: Up to 16,000 IOPS, 1,000 MiB/s
    - Cost-effective for most workloads
    
  io2 (Provisioned IOPS SSD):
    - Up to 64,000 IOPS per volume
    - Sub-millisecond latency
    - For I/O intensive applications

Root Volume Sizing:
  Development: 50GB gp3 (3,000 IOPS)
  Production:  100GB gp3 (6,000 IOPS)
  
Application Data Volumes:
  Log Storage:    20GB - 100GB per instance
  Temp Storage:   10GB - 50GB per instance
  Cache Storage:  5GB - 20GB per instance
```

#### 9.2.2 EFS Capacity Planning
```yaml
EFS Performance Modes:
  General Purpose:
    - Up to 7,000 file operations per second
    - Lower latency per operation
    - Suitable for most use cases
    
  Max I/O:
    - Higher levels of aggregate throughput
    - Higher latency per operation
    - For applications needing high IOPS

EFS Throughput Modes:
  Bursting:
    - Baseline: 100 MiB/s per TB stored
    - Burst: Up to 100 MiB/s
    - Cost-effective for variable workloads
    
  Provisioned:
    - Consistent throughput independent of size
    - Up to 500 MiB/s (eu-west-2)
    - For predictable performance needs

EFS Capacity Allocation:
  Scripts EFS:      10GB - 50GB
  SSL Certificates: 1GB - 5GB
  Configuration:    5GB - 20GB
  Logs/Temp:       20GB - 100GB
```

#### 9.2.3 RDS Storage Planning
```yaml
RDS Storage Types:
  gp3 (General Purpose SSD):
    - Baseline: 3,000 IOPS
    - Scalable: Up to 16,000 IOPS
    - Cost-effective for most databases
    
  io1/io2 (Provisioned IOPS):
    - Up to 80,000 IOPS (io2)
    - Consistent performance
    - For I/O intensive databases

RDS Storage Scaling:
  Initial Allocation: 50GB
  Maximum Size:      1TB (auto-scaling)
  Growth Increment:  10% or 20GB minimum
  
Storage Utilization Monitoring:
  Warning Threshold:  80% utilization
  Critical Threshold: 90% utilization
  Auto-scaling:       Enabled with 20% headroom
```

### 9.3 AWS Network Capacity Planning

#### 9.3.1 Network Performance by Instance Type
```yaml
Network Performance Tiers:
  Up to 10 Gbps:
    - t3.medium, t3.large, t3.xlarge
    - Suitable for moderate network traffic
    
  Up to 25 Gbps:
    - c5.2xlarge, c5.4xlarge
    - High network performance
    
  Enhanced Networking:
    - SR-IOV for higher PPS performance
    - Lower latency and jitter
    - Available on most modern instance types

Bandwidth Allocation:
  Frontend-ALB:     1-5 Gbps per instance
  Backend-Internal: 2-10 Gbps per instance
  Database:         5-25 Gbps (RDS Multi-AZ)
  EFS:             100 MiB/s - 500 MiB/s provisioned
```

#### 9.3.2 Application Load Balancer Capacity
```yaml
ALB Capacity Planning:
  Request Rate:     Up to 25,000 requests/second
  Concurrent Connections: Up to 3,000 per target
  Bandwidth:        No specific limit (scales automatically)
  
Target Group Health:
  Healthy Threshold:   2 consecutive checks
  Unhealthy Threshold: 3 consecutive checks
  Health Check Interval: 30 seconds
  Timeout:            5 seconds

Connection Draining:
  Deregistration Delay: 300 seconds
  Connection Idle Timeout: 60 seconds
```

#### 9.3.3 VPC Network Limits
```yaml
VPC Networking Limits:
  Subnets per VPC:           200
  Route Tables per VPC:      200
  Security Groups per VPC:   2,500
  Rules per Security Group:  60 inbound, 60 outbound
  
NAT Gateway Capacity:
  Bandwidth:    Up to 45 Gbps
  Connections:  Up to 55,000 simultaneous
  Ports:        1,024-65,535 per destination
```

### 9.4 AWS Auto Scaling Configuration

#### 9.4.1 Auto Scaling Groups (Future Implementation)
```yaml
Scaling Policies:
  Target Tracking:
    - CPU Utilization: 70%
    - Memory Utilization: 75%
    - Request Count: 1000 per target
    
  Step Scaling:
    - Scale Out: +2 instances when CPU > 80%
    - Scale In:  -1 instance when CPU < 30%
    
  Scheduled Scaling:
    - Business Hours: 8 AM - 6 PM (scale out)
    - Off Hours: 6 PM - 8 AM (scale in)

Instance Limits:
  Minimum: 2 instances (HA)
  Desired: 2-4 instances
  Maximum: 10 instances
```

#### 9.4.2 RDS Auto Scaling
```yaml
RDS Storage Auto Scaling:
  Enable: true
  Maximum Storage: 1000 GB
  Threshold: 90% utilization
  
RDS Read Replicas (Future):
  Maximum: 5 read replicas
  Cross-AZ: Enabled
  Promotion: Automatic failover
```

### 9.5 Monitoring and Alerting for Capacity

#### 9.5.1 CloudWatch Metrics
```yaml
EC2 Metrics:
  - CPUUtilization
  - MemoryUtilization (custom)
  - DiskSpaceUtilization (custom)
  - NetworkIn/NetworkOut
  - StatusCheckFailed

RDS Metrics:
  - CPUUtilization
  - DatabaseConnections
  - FreeStorageSpace
  - ReadLatency/WriteLatency
  - IOPS (ReadIOPS/WriteIOPS)

EFS Metrics:
  - TotalIOBytes
  - DataReadIOBytes/DataWriteIOBytes
  - MetadataIOBytes
  - PercentIOLimit

ALB Metrics:
  - RequestCount
  - TargetResponseTime
  - HTTPCode_Target_2XX_Count
  - UnHealthyHostCount
```

#### 9.5.2 Capacity Alerting Thresholds
```yaml
Critical Alerts (PagerDuty):
  - CPU > 90% for 5 minutes
  - Memory > 95% for 5 minutes
  - Disk > 95% utilization
  - Database connections > 90% of max
  
Warning Alerts (Email/Slack):
  - CPU > 80% for 10 minutes
  - Memory > 85% for 10 minutes
  - Disk > 85% utilization
  - Network errors > 1% of requests

Capacity Planning Alerts:
  - Storage growth rate > 10GB/week
  - Connection pool utilization > 75%
  - EFS throughput > 80% of provisioned
```

### 9.6 Cost Optimization Strategies

#### 9.6.1 Reserved Instances and Savings Plans
```yaml
Reserved Instance Strategy:
  Production Workloads:
    - 1-year term for predictable workloads
    - 3-year term for stable, long-term workloads
    - Standard RIs for consistent instance types
    
  Development/Staging:
    - On-demand instances for flexibility
    - Spot instances for non-critical workloads
    
Savings Plans:
  - Compute Savings Plans: 1-3 year commitment
  - EC2 Instance Savings Plans: Specific instance families
  - Target: 60-80% of steady-state compute usage
```

#### 9.6.2 Right-Sizing Recommendations
```yaml
Right-Sizing Process:
  1. Monitor utilization for 2-4 weeks
  2. Identify over-provisioned instances
  3. Test smaller instance types in staging
  4. Implement changes during maintenance windows
  
Right-Sizing Targets:
  - CPU: 60-80% average utilization
  - Memory: 70-85% average utilization
  - Network: 40-60% of instance capacity
  - Storage IOPS: 60-80% of provisioned
```

### 9.7 Performance Specifications

#### 9.7.1 Capacity Planning Baselines
```yaml
Development Environment:
  - Concurrent Users: 10-20
  - API Requests/min: 100-500
  - Database Connections: 10-50
  - Storage: 100GB total
  - Network: 1-5 Gbps aggregate

Production Environment:
  - Concurrent Users: 100-500
  - API Requests/min: 1000-5000
  - Database Connections: 100-500
  - Storage: 1TB+ with auto-scaling
  - Network: 10-25 Gbps aggregate
```

#### 9.7.2 Performance Targets
```yaml
Response Times:
  - Web Pages: < 2 seconds
  - API Calls: < 500ms
  - Database Queries: < 100ms
  - File Operations: < 1 second

Availability:
  - Single Node: 99.0% (8.76 hours/month downtime)
  - HA Deployment: 99.9% (43.2 minutes/month downtime)
  - RDS Multi-AZ: 99.95% (21.6 minutes/month downtime)
```

#### 9.7.3 Scalability Considerations
```yaml
Horizontal Scaling:
  - Frontend: 2-10 instances (ALB distribution)
  - Backend: 2-10 instances (internal ALB)
  - Keystone: 2-5 instances (shared fernet keys)
  - RabbitMQ: 2-5 instances (cluster formation)

Vertical Scaling:
  - Instance Types: t3.medium → c5.4xlarge
  - RDS: db.t3.medium → db.c5.4xlarge
  - EFS: Provisioned throughput scaling
```

### 9.8 Capacity Management Procedures

#### 9.8.1 Regular Capacity Reviews
```yaml
Review Schedule:
  Weekly:    Resource utilization trends
  Monthly:   Capacity planning adjustments
  Quarterly: Right-sizing and cost optimization
  Annually:  Architecture review and scaling strategy

Capacity Planning Tools:
  - AWS Cost Explorer: Usage patterns and trends
  - AWS Trusted Advisor: Right-sizing recommendations
  - CloudWatch Insights: Custom capacity queries
  - AWS Compute Optimizer: ML-based recommendations
```

#### 9.8.2 Capacity Testing Procedures
```yaml
Load Testing:
  - Baseline performance testing
  - Stress testing at 150% expected load
  - Endurance testing for 24-48 hours
  - Failover testing for HA scenarios

Capacity Validation:
  - Performance benchmarking
  - Resource utilization analysis
  - Bottleneck identification
  - Scaling behavior verification
```

---

**Document Version**: 1.1  
**Last Updated**: 2024-12-20  
**Author**: Infrastructure Team  
**Approved By**: Technical Architecture Board