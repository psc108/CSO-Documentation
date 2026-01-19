#!/bin/bash
# Transfer LLD content to SecureCloud template
# This script creates a properly formatted LLD document using the template

set -e

SCRIPT_DIR="/home/scottp/IdeaProjects/CSO-Documentation"
TEMPLATE="$SCRIPT_DIR/docx/Templates/SecureCloud_service_LLD_xxx_Template_v0.1.docx"
LLD_MD="$SCRIPT_DIR/LLD.md"
OUTPUT="$SCRIPT_DIR/docx/LLD_SecureCloud_Final.docx"
TEMP_DIR="/tmp/lld_merge_$$"

echo "========================================="
echo "LLD Template Merge Process"
echo "========================================="

mkdir -p "$TEMP_DIR"

cat > "$TEMP_DIR/lld_formatted.md" << 'MDEOF'
# 1. Introduction

## 1.1 Purpose

This document provides the detailed technical design for the UK MSVX CPS (Chief Security Officer Shared Services Portal) infrastructure deployment on AWS using Terraform modular architecture.

## 1.2 Scope

This Low Level Design covers:

- Detailed component specifications and configurations
- Network architecture with security groups and routing
- Service configurations and inter-dependencies
- Database design and storage architecture
- Deployment automation and orchestration procedures
- Capacity planning and performance specifications

## 1.3 Architecture Summary

The UK MSVX CPS infrastructure consists of multiple tiers deployed across AWS availability zones with the following components:

- **Presentation Layer**: Application Load Balancer with SSL termination and Cognito authentication
- **Application Layer**: Frontend servers (port 8102), Backend services (13 microservices on ports 8090-8105)
- **Identity Layer**: OpenStack Keystone identity service (port 5000)
- **Integration Layer**: RabbitMQ message broker cluster (ports 5672/5671)
- **Data Layer**: RDS MySQL Multi-AZ database, EFS shared storage, S3 object storage
- **Management Layer**: Jump server with admin interface and deployment scripts

# 2. Infrastructure Components

## 2.1 Terraform Module Architecture

The infrastructure is deployed using a modular Terraform architecture with the following modules:

### Module Structure

- **networking**: VPC, subnets, ALB, NAT gateways, security groups
- **security**: IAM roles, SSL certificates, KMS encryption
- **compute**: EC2 instances, user data scripts, target groups
- **storage**: EFS file systems, S3 buckets, access points
- **database**: RDS MySQL, subnet groups, parameter groups, monitoring
- **dns**: Route53 private hosted zones, DNS records, health checks

### Environment Configuration

Environment-specific configurations are managed through YAML files:

```yaml
# env.prod-ha.yaml
prod: true
ha: true
vpc_name: CSO-prod-ha
vpc_cidr: 10.1.0.0/16
jump_server_access_cidrs:
  - 10.0.0.0/8
  - 172.16.0.0/12
admin_email: "admin@company.com"
```

## 2.2 Networking Module

### 2.2.1 VPC Configuration

**VPC Specifications:**
- **CIDR Blocks**: Development: 10.0.0.0/24 (256 IPs), Staging/Production: 10.x.0.0/16 (65,536 IPs)
- **DNS Resolution**: Enabled for service discovery
- **DNS Hostnames**: Enabled for internal DNS
- **Region**: eu-west-2 (London)
- **Availability Zones**: eu-west-2a (primary), eu-west-2c (secondary)

### 2.2.2 Subnet Design

**Public Subnets** (ALB, NAT Gateways):
- eu-west-2a: First half of upper CIDR range
- eu-west-2c: Second half of upper CIDR range

**Private Subnets** (Application Servers):
- eu-west-2a: First half of lower CIDR range
- eu-west-2c: Second half of lower CIDR range

### 2.2.3 Application Load Balancer (HA Only)

**Load Balancer Specifications:**
- **Type**: Application Load Balancer (Layer 7)
- **Scheme**: Internet-facing
- **SSL Policy**: ELBSecurityPolicy-TLS-1-2-2017-01
- **Cross-Zone Load Balancing**: Enabled
- **Deletion Protection**: Enabled for production
- **Access Logs**: Enabled to S3 bucket

**Target Groups:**

Frontend Target Group:
- Port: 8102
- Protocol: HTTP
- Health Check Path: /ui/management/login/system
- Healthy Threshold: 2 consecutive checks
- Unhealthy Threshold: 3 consecutive checks
- Timeout: 5 seconds
- Interval: 30 seconds
- Matcher: 200

Keystone Target Group:
- Port: 5000
- Protocol: HTTPS
- Health Check Path: /api/idm/v3
- Matcher: 200,300
- Timeout: 10 seconds

## 2.3 Security Module

### 2.3.1 Security Groups

**Security Group Matrix:**

| Service | Inbound Ports | Source | Purpose |
|---------|---------------|--------|---------|
| Frontend LB | 80, 443, 8102 | 0.0.0.0/0 | Public web access |
| Frontend | 8102, 443, 80 | ALB SG | Web traffic from ALB |
| Backend | 8080-8105 | Core SG | API services |
| Keystone | 5000 | Core SG | Identity API |
| RabbitMQ | 5672, 15671 | Core SG | Messaging |
| Jump Server | 8081 | ALB SG | Admin interface |
| RDS MySQL | 3306 | Core SG | Database access |
| EFS | 2049 | Core SG, Jump SG | NFS file access |

**Core Servers Security Group:**
- All TCP ports from self (inter-server communication)
- Port 3306 from self (MySQL access)
- All outbound traffic allowed

### 2.3.2 IAM Roles and Policies

**EC2 Instance Role:**
- Role Name: {environment}-ec2-ssm-role
- Attached Policies:
  - AmazonSSMManagedInstanceCore (SSM access)
  - AmazonSSMPatchAssociation (patch management)
  - CloudWatchAgentServerPolicy (monitoring)
  - Custom S3 read access policy
  - Custom Secrets Manager read access policy

**S3 Bucket Policies:**
- Read-only access to CSO installation files
- Write access to backup buckets
- Encryption enforcement

### 2.3.3 SSL Certificate Management

**Certificate Hierarchy:**
- Root CA: 30-year validity, RSA 4096-bit
- Intermediate CA: 20-year validity, RSA 4096-bit
- Server Certificates: 10-year validity, RSA 2048-bit

**Certificate Storage:**
- Generated on Jump Server
- Stored in EFS (/opt/ssl-certs)
- Mounted on all service servers
- Backed up to S3

## 2.4 Compute Module

### 2.4.1 Instance Specifications

**Production Sizing:**

| Service | Instance Type | vCPU | Memory | Storage | IOPS |
|---------|---------------|------|--------|---------|------|
| Frontend | c5.2xlarge | 8 | 16 GB | 50 GB GP3 | 3000 |
| Backend | c5.4xlarge | 16 | 32 GB | 50 GB GP3 | 3000 |
| Keystone | t2.xlarge | 4 | 16 GB | 50 GB GP3 | 3000 |
| RabbitMQ | t2.xlarge | 4 | 16 GB | 50 GB GP3 | 3000 |
| Jump Server | t2.large | 2 | 8 GB | 50 GB GP3 | 3000 |

**Development Sizing:**

| Service | Instance Type | vCPU | Memory | Storage | IOPS |
|---------|---------------|------|--------|---------|------|
| Frontend | t2.xlarge | 4 | 16 GB | 50 GB GP3 | 3000 |
| Backend | t2.2xlarge | 8 | 32 GB | 50 GB GP3 | 3000 |
| Keystone | t2.medium | 2 | 4 GB | 50 GB GP3 | 3000 |
| RabbitMQ | t2.xlarge | 4 | 16 GB | 50 GB GP3 | 3000 |
| Jump Server | t2.large | 2 | 8 GB | 50 GB GP3 | 3000 |

### 2.4.2 User Data and Initialization

All instances execute common initialization:
- System updates (dnf update -y)
- Install SSM agent, NFS utilities, Java 21
- Mount EFS filesystems (/opt/scripts, /opt/ssl-certs)
- Execute service-specific setup script
- Configure CloudWatch agent

### 2.4.3 Service Dependencies

Deployment sequence:
1. Jump Server setup and EFS population
2. Keystone servers (identity service)
3. RabbitMQ cluster formation
4. Frontend and Backend servers
5. Health validation and testing

## 2.5 Storage Module

### 2.5.1 EFS File Systems

**Main Scripts EFS:**
- Creation Token: {environment}-efs
- Encryption: KMS encryption enabled
- Performance Mode: General Purpose
- Throughput Mode: Provisioned (100 MiB/s)
- Lifecycle Policy: Transition to IA after 30 days
- Mount Targets: One per private subnet
- Access Points: POSIX permissions (uid:1000, gid:1000)

**SSL Certificates EFS:**
- Creation Token: {environment}-ssl-certs
- Encryption: KMS encryption enabled
- Throughput Mode: Provisioned (50 MiB/s)
- Dedicated for certificate storage

### 2.5.2 S3 Bucket Configuration

**CSO Files Bucket:**
- Bucket Name: {environment}-cso-files
- Encryption: AES256 server-side encryption
- Versioning: Enabled
- Lifecycle Rules: Archive to Glacier after 90 days
- Access: IAM role-based

**ALB Logs Bucket:**
- Bucket Name: {environment}-alb-logs
- Encryption: Enabled
- Lifecycle: Delete after 30 days

## 2.6 Database Module

### 2.6.1 RDS MySQL Configuration

**Database Specifications:**
- Engine: MySQL 8.0.42
- Instance Class: Production: db.c5.4xlarge, Development: db.t3.2xlarge
- Storage: GP3 SSD, 50GB initial, auto-scaling to 1TB
- Multi-AZ: Enabled for HA deployments
- Backup Retention: Production: 30 days, Development: 7 days
- Backup Window: 03:00-04:00 UTC
- Maintenance Window: Sunday 04:00-05:00 UTC
- Performance Insights: Enabled with 7-day retention
- Enhanced Monitoring: 60-second interval
- Encryption: KMS encryption at rest
- SSL/TLS: Required for connections

### 2.6.2 Database Schema Design

**Keystone Database:**
- Database Name: keystone
- User: keystone
- Tables: user, project, role, token, credential, policy

**CSO Application Database:**
- Database Name: cso_portal
- User: cso_user
- Tables: customers, services, orders, configurations, audit_logs

## 2.7 DNS Module

### 2.7.1 Private Hosted Zone

- Zone Name: {environment}.cso.ss (e.g., dev-ha.cso.ss)
- VPC Association: Main VPC
- DNS Resolution: Enabled

### 2.7.2 DNS Records

**Server A Records:**
- frontend-server-1.{env}.cso.ss → Private IP
- backend-server-1.{env}.cso.ss → Private IP
- keystone01.{env}.cso.ss → Private IP
- rabbitmq-server-1.{env}.cso.ss → Private IP
- jump-server.{env}.cso.ss → Private IP
- mysql.{env}.cso.ss → RDS endpoint

**Service CNAME Records:**
- api.{env}.cso.ss → backend-server-1
- portal.{env}.cso.ss → frontend-server-1
- identity.{env}.cso.ss → keystone01
- mq.{env}.cso.ss → rabbitmq-server-1

# 3. Service-Level Design

## 3.1 Frontend Service Architecture

### 3.1.1 Nginx Configuration

- Listen Port: 8102
- Health Check Endpoint: /health
- Management UI Path: /ui/management/ → localhost:8080
- Portal UI Path: /ui/portal/ → localhost:8202
- Proxy Headers: Host, X-Real-IP, X-Forwarded-For
- SSL: Configured for HTTPS termination

### 3.1.2 CSO Application Integration

- Management UI Port: 8102 (ALB target)
- Portal UI Port: 8202 (internal)
- Backend Communication: HTTP to backend services
- Authentication: Keystone token validation
- Session Management: Redis-based (future enhancement)

## 3.2 Backend Service Architecture

### 3.2.1 Service Port Allocation

- apidoc: 8098 (API Documentation)
- blobstore: 8091 (Binary Large Object Store)
- catalog: 8093 (Service Catalog)
- config: 8103 (Configuration Service)
- customers: 8090 (Customer Management)
- event: 8092 (Event Processing)
- export: 8105 (Data Export)
- fulfillment: 8097 (Order Fulfillment)
- pricing: 8100 (Pricing Engine)
- reporting: 8099 (Reporting Service)
- request: 8096 (Request Management)
- svcinst: 8094 (Service Instances)
- ticketing: 8101 (Ticketing System)

### 3.2.2 Backend Load Balancer (HA)

- Type: Internal Application Load Balancer
- Subnets: Private subnets only
- Target Groups: One per backend service
- Health Checks: Service-specific endpoints

## 3.3 Keystone Identity Service

### 3.3.1 OpenStack Keystone Configuration

**keystone.conf:**
- Database Connection: MySQL via private DNS
- Token Provider: Fernet tokens
- Token Expiration: 3600 seconds (1 hour)
- Fernet Key Repository: /etc/keystone/fernet-keys (EFS-backed)
- Message Queue: RabbitMQ via private DNS

### 3.3.2 Apache WSGI Configuration

- Virtual Host: Port 5000
- SSL: Enabled with server certificates
- WSGI Daemon: Python 3.9 virtual environment
- WSGI Script: /usr/local/bin/keystone-wsgi-public

### 3.3.3 Keystone Clustering

- Fernet Key Synchronization: EFS-based shared storage
- Token Validation: Cross-server compatible
- Database: Shared RDS MySQL
- Health Check: /api/idm/v3 endpoint

## 3.4 RabbitMQ Message Broker

### 3.4.1 RabbitMQ Configuration

- TCP Port: 5672
- SSL Port: 5671
- Management Port: 15671 (HTTPS)
- SSL Certificates: Server-specific from EFS
- Erlang Cookie: Shared via EFS for clustering

### 3.4.2 RabbitMQ Clustering

- Cluster Formation: Classic config with static nodes
- Node Names: rabbit@rabbitmq-server-1, rabbit@rabbitmq-server-2
- HA Policy: ha-all (mirror all queues)
- Queue Mirroring: Enabled across all nodes
- Network Partition Handling: autoheal mode

## 3.5 Jump Server Administration

### 3.5.1 Admin Interface

- Flask-based web interface on port 8080
- Service health monitoring dashboard
- RabbitMQ cluster status
- Keystone service status
- Database connection status

### 3.5.2 Service Management Scripts

- unified-server-setup.sh: Universal setup script
- keystone-setup.sh: Keystone identity service setup
- rabbitmq-setup.sh: Message broker setup
- frontend-setup.sh: Web frontend setup
- backend-setup.sh: API backend setup
- test-keystone-cluster.sh: Keystone cluster health
- test-rabbitmq-cluster-health.sh: RabbitMQ cluster health

# 4. Network Security Design

## 4.1 Security Group Rules

### 4.1.1 Frontend Load Balancer Security Group

**Inbound:**
- Port 80 (HTTP) from 0.0.0.0/0
- Port 443 (HTTPS) from 0.0.0.0/0
- Port 8102 (CSO) from 0.0.0.0/0

**Outbound:**
- All traffic to 0.0.0.0/0

### 4.1.2 Core Servers Security Group

**Inbound:**
- All TCP ports from self (inter-server communication)
- Port 3306 from self (MySQL access)

**Outbound:**
- All traffic to 0.0.0.0/0

### 4.1.3 EFS Security Group

**Inbound:**
- Port 2049 (NFS) from Core Servers SG
- Port 2049 (NFS) from Jump Server SG

**Outbound:**
- All traffic to 0.0.0.0/0

## 4.2 VPC Endpoints

**SSM VPC Endpoints:**
- com.amazonaws.eu-west-2.ssm
- com.amazonaws.eu-west-2.ssmmessages
- com.amazonaws.eu-west-2.ec2messages

**S3 VPC Endpoint:**
- com.amazonaws.eu-west-2.s3 (Gateway endpoint)

# 5. Data Flow and Integration

## 5.1 Authentication Flow

1. User → ALB (HTTPS:443)
2. ALB → Cognito Authentication (HA only)
3. Cognito → ALB (OAuth2 callback)
4. ALB → Frontend Server (HTTP:8102)
5. Frontend → Keystone (HTTPS:5000) for token validation
6. Keystone → RDS MySQL for user verification
7. Frontend → Backend Services with authenticated requests

## 5.2 Service Communication

- Frontend (8102) ↔ Backend Services (8090-8105)
- All Services → Keystone (5000) for authentication
- All Services → RabbitMQ (5672/5671) for messaging
- All Services → RDS MySQL (3306) for data persistence

## 5.3 File and Configuration Management

- S3 Bucket → Jump Server (download installation files)
- Jump Server → EFS (/opt/scripts, /opt/ssl-certs)
- All Servers → EFS (NFS mounts for shared access)

# 6. Monitoring and Logging

## 6.1 CloudWatch Integration

**EC2 Instance Monitoring:**
- Detailed monitoring enabled (1-minute intervals)
- Custom metrics: Memory, Disk, Application-specific

**RDS Performance Insights:**
- Enabled with 7-day retention
- Enhanced monitoring at 60-second intervals

**Application Load Balancer:**
- Access logs to S3
- Request metrics and error rates

## 6.2 Log Aggregation

**Application Logs:**
- /var/log/cso-setup.log
- /var/log/keystone-setup-progress.log
- /var/log/rabbitmq-setup-progress.log
- /var/log/efs-s3-sync.log

**System Logs:**
- /var/log/cloud-init-output.log
- /var/log/httpd/keystone.log
- /var/log/rabbitmq/

## 6.3 Health Check Endpoints

- GET /health (Frontend health)
- GET /api/idm/v3 (Keystone API health)
- GET /api/overview (RabbitMQ management)
- GET /admin/ (Jump server admin interface)

# 7. Backup and Recovery

## 7.1 RDS Backup Strategy

- Automated daily backups
- Backup Window: 03:00-04:00 UTC
- Retention: Production: 30 days, Development: 7 days
- Point-in-time recovery enabled
- Final snapshot on deletion (production only)

## 7.2 EFS Backup

- Lifecycle Policy: Transition to IA after 30 days
- AWS Backup integration for snapshots
- Cross-region replication (production)

## 7.3 Configuration Backup

- Terraform State: S3 with versioning
- State Locking: DynamoDB table
- Application Configuration: EFS snapshots
- Installation Packages: S3 versioning

# 8. Deployment Automation

## 8.1 Terraform Deployment Process

**Deployment Commands:**
```bash
terraform workspace select prod-ha
./deploy.ps1 -AutoApprove
```

**Deployment Phases:**
1. Infrastructure provisioning (5-10 minutes)
2. Jump server setup (10-15 minutes)
3. Service dependencies (15-30 minutes)
4. Application installation (30-60 minutes)
5. Health validation (5-10 minutes)

**Total Deployment Time:** 65-125 minutes

## 8.2 Rollback Procedures

**Infrastructure Rollback:**
- terraform destroy for complete teardown
- terraform taint for specific resource recreation

**Service Rollback:**
- Git revert for configuration changes
- Redeploy with previous version

# 9. Capacity Planning

## 9.1 Compute Capacity

**CPU Utilization Targets:**
- Development: 40-60% average, 80% peak
- Production: 60-75% average, 90% peak

**Memory Allocation:**
- Frontend: 8GB-16GB total (Java heap + OS)
- Backend: 16GB-32GB total (Java heap + OS)
- Keystone: 4GB-16GB total (Python + Apache)
- RabbitMQ: 8GB-16GB total (Erlang VM + messages)

## 9.2 Storage Capacity

**EBS Volumes:**
- Root: 50GB-100GB GP3 (3,000-6,000 IOPS)
- Logs: 20GB-100GB per instance
- Cache: 5GB-20GB per instance

**EFS Capacity:**
- Scripts: 10GB-50GB
- SSL Certificates: 1GB-5GB
- Configuration: 5GB-20GB

**RDS Storage:**
- Initial: 50GB
- Maximum: 1TB (auto-scaling)
- Growth: 10% or 20GB minimum increments

## 9.3 Network Capacity

**Bandwidth Allocation:**
- Frontend-ALB: 1-5 Gbps per instance
- Backend-Internal: 2-10 Gbps per instance
- Database: 5-25 Gbps (RDS Multi-AZ)
- EFS: 100-500 MiB/s provisioned

**ALB Capacity:**
- Request Rate: Up to 25,000 requests/second
- Concurrent Connections: Up to 3,000 per target

## 9.4 Performance Targets

**Response Times:**
- Web Pages: < 2 seconds
- API Calls: < 500ms
- Database Queries: < 100ms

**Availability:**
- Development: 99.0% (8.76 hours/month downtime)
- Production HA: 99.9% (43.2 minutes/month downtime)

# 10. Assumptions

The following assumptions have been made in this design:

1. AWS eu-west-2 (London) region is approved and available
2. Network connectivity to AWS is reliable and sufficient
3. Required AWS service quotas are available or can be increased
4. DNS management is handled externally or via Route53
5. SSL certificates are self-signed or provided by the organization
6. Backup retention policies comply with organizational requirements
7. Disaster recovery procedures are documented separately
8. Application code and packages are provided and tested
9. User authentication via Cognito is acceptable for HA environments
10. CloudWatch logging meets compliance and audit requirements
11. Terraform version 1.5+ is available for deployment
12. PowerShell or Bash is available for deployment scripts
13. AWS CLI is configured with appropriate credentials
14. Git repository is available for version control
15. Jump server has internet access for package downloads

# 11. Dependencies

This solution has the following dependencies:

1. **AWS Account**: Active account with appropriate permissions and service limits
2. **Terraform**: Version 1.5+ for infrastructure deployment
3. **Git Repository**: For configuration management and version control
4. **SSL Certificates**: Valid certificates for HTTPS endpoints (self-signed or CA-issued)
5. **DNS Services**: Route53 or external DNS for domain name resolution
6. **Application Packages**: CSO application installation files and dependencies
7. **OpenStack Keystone**: Identity service packages and configuration
8. **RabbitMQ**: Message broker packages and Erlang runtime
9. **MySQL Client**: For database initialization and management
10. **AWS CLI**: Configured with credentials for S3 and Secrets Manager access
11. **Java Runtime**: Java 21 LTS for backend services
12. **Python Runtime**: Python 3.9+ for Keystone and admin scripts
13. **Nginx/Apache**: Web servers for frontend and Keystone
14. **CloudWatch Agent**: For custom metrics and log aggregation
15. **SSM Agent**: For secure instance access and management

# 12. Definitions and Conventions

| Abbreviation | Definition |
|--------------|------------|
| ALB | Application Load Balancer |
| AMQP | Advanced Message Queuing Protocol |
| API | Application Programming Interface |
| AZ | Availability Zone |
| CIDR | Classless Inter-Domain Routing |
| CSO | Chief Security Officer |
| DNS | Domain Name System |
| DR | Disaster Recovery |
| EBS | Elastic Block Store |
| EC2 | Elastic Compute Cloud |
| EFS | Elastic File System |
| GP3 | General Purpose SSD version 3 |
| HA | High Availability |
| HLD | High Level Design |
| HTTP | Hypertext Transfer Protocol |
| HTTPS | HTTP Secure |
| IAM | Identity and Access Management |
| IOPS | Input/Output Operations Per Second |
| KMS | Key Management Service |
| LLD | Low Level Design |
| MSVX | Multi-Service Virtual Exchange |
| NAT | Network Address Translation |
| NFS | Network File System |
| POSIX | Portable Operating System Interface |
| RBAC | Role-Based Access Control |
| RDS | Relational Database Service |
| RPO | Recovery Point Objective |
| RTO | Recovery Time Objective |
| S3 | Simple Storage Service |
| SG | Security Group |
| SSL | Secure Sockets Layer |
| SSM | Systems Manager |
| TLS | Transport Layer Security |
| VPC | Virtual Private Cloud |
| WSGI | Web Server Gateway Interface |
| YAML | YAML Ain't Markup Language |

MDEOF

echo "Step 2: Converting to DOCX with template..."
pandoc "$TEMP_DIR/lld_formatted.md" \
    -o "$OUTPUT" \
    --reference-doc="$TEMPLATE" \
    -f markdown \
    -t docx \
    --toc \
    --toc-depth=3

echo ""
echo "========================================="
echo "✓ Conversion Complete!"
echo "========================================="
echo "Output: $OUTPUT"
echo ""
echo "NEXT STEPS:"
echo "1. Open the document in Microsoft Word or LibreOffice"
echo "2. Update the cover page metadata (author, date, version)"
echo "3. Fill in the Document Information table"
echo "4. Update Version History table"
echo "5. Add Document References if needed"
echo "6. Update Table of Contents (right-click → Update Field)"
echo "7. Review formatting and adjust as needed"
echo "8. Verify all technical specifications and configurations"
echo ""

rm -rf "$TEMP_DIR"
