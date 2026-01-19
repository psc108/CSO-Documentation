#!/bin/bash
# Transfer HLD content to SecureCloud template
# This script creates a properly formatted HLD document using the template

set -e

SCRIPT_DIR="/home/scottp/IdeaProjects/CSO-Documentation"
TEMPLATE="$SCRIPT_DIR/docx/Templates/SecureCloud_service_HLD_xxx_Template_v0.1.docx"
HLD_MD="$SCRIPT_DIR/HLD.md"
OUTPUT="$SCRIPT_DIR/docx/HLD_SecureCloud_Final.docx"
TEMP_DIR="/tmp/hld_merge_$$"

echo "========================================="
echo "HLD Template Merge Process"
echo "========================================="

# Create temp directory
mkdir -p "$TEMP_DIR"

# Step 1: Create a modified markdown with template-friendly structure
echo "Step 1: Preparing content for template..."
cat > "$TEMP_DIR/hld_formatted.md" << 'MDEOF'
# 1. General Description

## 1.1 Introduction

This document describes the high-level architecture for the UK MSVX CPS (Chief Security Officer Shared Services Portal) infrastructure deployment on AWS. The solution provides a scalable, highly available multi-tier application platform supporting identity management, service orchestration, and administrative interfaces.

### Business Context

The UK MSVX CPS serves as a centralized portal for managing cloud services and security operations, providing:

- **Identity and Access Management** via OpenStack Keystone
- **Service Catalog and Orchestration** capabilities
- **Message Queuing and Event Processing** through RabbitMQ
- **Administrative and User Interfaces** for portal management
- **Reporting and Analytics** for operational insights

## 1.2 In Scope

The following components are within the scope of this HLD:

- AWS infrastructure architecture (VPC, subnets, security groups)
- Multi-tier application deployment (Frontend, Backend, Keystone, RabbitMQ)
- High availability and disaster recovery design
- Security architecture and access controls
- Integration patterns and data flows
- Operational procedures and monitoring
- Scalability and performance considerations

## 1.3 Out of Scope

The following items are outside the scope of this document:

- Detailed application code implementation
- Low-level configuration parameters (covered in LLD)
- Specific operational runbooks (covered in Operations Guide)
- Cost analysis and budgeting details
- Third-party service integrations beyond AWS

# 2. Solution Overview

The UK MSVX CPS infrastructure consists of multiple tiers deployed across AWS availability zones:

**Presentation Layer**: Application Load Balancer with AWS Cognito authentication, Frontend servers hosting Management UI and Portal UI

**Application Layer**: Backend services (13 microservices), API Gateway, Admin Interface

**Identity & Integration Layer**: OpenStack Keystone for identity management, RabbitMQ cluster for message queuing

**Data Layer**: Amazon RDS MySQL (Multi-AZ), Amazon EFS for shared storage, Amazon S3 for backups

# 3. Architectural Overview

## 3.1 Design Principles

The architecture follows these core principles:

- **High Availability**: Multi-AZ deployment with automated failover
- **Scalability**: Horizontal and vertical scaling capabilities
- **Security**: Defense in depth with multiple security layers
- **Automation**: Infrastructure as Code with Terraform
- **Observability**: Comprehensive monitoring and logging
- **Cost Optimization**: Environment-specific resource sizing

## 3.2 Solution Components

### Technology Stack

- **Cloud Platform**: Amazon Web Services (AWS)
- **Infrastructure as Code**: Terraform with modular architecture
- **Operating System**: Amazon Linux 2023
- **Application Runtime**: Java 21 LTS, Python 3.9+
- **Web Server**: Nginx, Apache HTTP Server
- **Database**: MySQL 8.0 on Amazon RDS
- **Message Broker**: RabbitMQ with clustering
- **Identity Service**: OpenStack Keystone
- **Monitoring**: AWS CloudWatch, Performance Insights

### Service Portfolio

The backend consists of 13 microservices:

- API Documentation (8098)
- Blob Store (8091)
- Service Catalog (8093)
- Data Export (8105)
- Pricing Engine (8100)
- Request Management (8096)
- Configuration Service (8103)
- Customer Management (8090)
- Event Processing (8092)
- Order Fulfillment (8097)
- Reporting Service (8099)
- Service Instances (8094)
- Ticketing System (8101)

# 4. Resilience and Availability

## 4.1 High Availability Design

**Multi-AZ Deployment**: All critical components deployed across two availability zones (eu-west-2a, eu-west-2c)

**Load Balancing**: Application Load Balancer distributes traffic across frontend instances

**Database**: RDS MySQL Multi-AZ with automatic failover

**Message Queue**: RabbitMQ cluster with mirrored queues

## 4.2 Recovery Objectives

- **RTO (Recovery Time Objective)**: 4 hours
- **RPO (Recovery Point Objective)**: 1 hour
- **Availability Target**: 99.9% (43.2 minutes/month downtime)

## 4.3 Backup Strategy

- **Database**: Automated daily backups with 30-day retention, point-in-time recovery
- **Configuration**: Git version control and EFS snapshots
- **Infrastructure**: Terraform state versioning

# 5. Security

## 5.1 Security Architecture

The security architecture implements defense in depth across multiple layers:

### Network Security
- VPC isolation with private subnets for application components
- Security groups for fine-grained access control
- Network ACLs for additional filtering
- NAT Gateways for outbound internet access

### Application Security
- AWS Cognito for user authentication (HA environments)
- OpenStack Keystone for service-level identity management
- Role-based access control (RBAC)
- Session management and token validation

### Data Security
- Encryption at rest: EBS volumes, RDS database, EFS file systems, S3 buckets
- Encryption in transit: SSL/TLS for all communications
- Database access controls and credential management
- AWS Secrets Manager for sensitive data

### Infrastructure Security
- IAM roles and policies following least privilege
- AWS SSM Session Manager for secure administrative access (no SSH keys)
- CloudTrail for comprehensive audit logging
- AWS Config for configuration compliance monitoring

# 6. Licensing

The solution utilizes the following licensed components:

- **AWS Services**: Pay-as-you-go pricing model
- **Operating System**: Amazon Linux 2023 (included with EC2)
- **OpenStack Keystone**: Open source (Apache License 2.0)
- **RabbitMQ**: Open source (Mozilla Public License)
- **MySQL**: Community Edition on RDS

No additional third-party licenses required for core infrastructure.

# 7. Additional Architecture Details

## 7.1 Deployment Models

### Development Environment
- Single AZ deployment for cost optimization
- Direct EIP access to frontend
- Simplified configuration
- Basic monitoring

### Production Environment
- Multi-AZ HA deployment
- Application Load Balancer with Cognito
- Enhanced monitoring and alerting
- Automated backups and disaster recovery

## 7.2 Network Architecture

### VPC Design
- **Production**: 10.1.0.0/16 (65,536 IPs)
- **Staging**: 10.2.0.0/16 (65,536 IPs)
- **Development**: 10.0.0.0/24 (256 IPs)

### Subnet Strategy
- **Public Subnets**: ALB, NAT Gateways
- **Private Subnets**: Application servers, databases

## 7.3 Integration Architecture

### Authentication Flow
User Request → ALB → Cognito Auth → Frontend → Keystone → Backend Services

### Service Communication
- **Synchronous**: Frontend ↔ Backend (HTTPS), Backend ↔ Keystone (HTTPS)
- **Asynchronous**: Services ↔ RabbitMQ (AMQP)

## 7.4 Operational Architecture

### Deployment Process
1. Infrastructure provisioning via Terraform (5-10 minutes)
2. Jump server setup and file preparation (10-15 minutes)
3. Service dependencies and clustering (15-30 minutes)
4. Application installation and configuration (30-60 minutes)
5. Health validation and testing (5-10 minutes)

**Total Deployment Time**: 65-125 minutes

### Monitoring Strategy
- AWS CloudWatch for metrics and alarms
- RDS Performance Insights for database monitoring
- ALB access logs for request analysis
- VPC Flow Logs for network traffic
- Custom application health checks

## 7.5 Scalability and Performance

### Performance Targets
- **Web Pages**: < 2 seconds response time
- **API Calls**: < 500 milliseconds
- **Database Queries**: < 100 milliseconds
- **Concurrent Users**: 100-500 (production)

### Scaling Strategy
- **Horizontal**: Add instances across availability zones
- **Vertical**: Upgrade instance types (t2.medium → c5.4xlarge)
- **Database**: Auto-scaling storage, read replicas for future enhancement

## 7.6 Cost Optimization

### Cost Management
- Environment-specific instance sizing
- EFS lifecycle policies (Infrequent Access after 30 days)
- RDS auto-scaling storage
- VPC endpoints for AWS service access
- Reserved Instances for production workloads

### Resource Tagging
- Environment: dev, staging, prod-ha
- Project: CSO HA Primary
- Owner: CSO Team
- CostCenter: Nimbus

## 7.7 Future Roadmap

### Short Term (3-6 months)
- Auto Scaling Groups implementation
- Enhanced monitoring and alerting
- Automated testing integration

### Medium Term (6-12 months)
- Container migration (Amazon EKS)
- Service mesh implementation
- Multi-region deployment

### Long Term (12+ months)
- Serverless components
- AI/ML integration
- Edge computing capabilities

# 8. Assumptions

The following assumptions have been made in this design:

1. AWS eu-west-2 (London) region is approved for deployment
2. Network connectivity to AWS is available and reliable
3. Required AWS service quotas are available
4. DNS management is handled externally
5. SSL certificates are provided by the organization
6. Backup retention policies comply with organizational requirements
7. Disaster recovery procedures are documented separately
8. Application code is provided and tested
9. User authentication via Cognito is acceptable for HA environments
10. CloudWatch logging meets compliance requirements

# 9. Dependencies

This solution has dependencies on:

1. **AWS Account**: Active AWS account with appropriate permissions
2. **Terraform**: Version 1.5+ for infrastructure deployment
3. **Git Repository**: For configuration and code management
4. **SSL Certificates**: Valid certificates for HTTPS endpoints
5. **DNS Services**: For domain name resolution
6. **Application Packages**: CSO application installation files
7. **OpenStack Keystone**: Identity service configuration
8. **RabbitMQ**: Message broker setup and clustering
9. **Monitoring Tools**: CloudWatch agent and custom metrics
10. **Backup Services**: AWS Backup for EFS and RDS

# 10. Definitions and Conventions

| Abbreviation | Definition |
|--------------|------------|
| ALB | Application Load Balancer |
| AZ | Availability Zone |
| CSO | Chief Security Officer |
| DR | Disaster Recovery |
| EBS | Elastic Block Store |
| EC2 | Elastic Compute Cloud |
| EFS | Elastic File System |
| HA | High Availability |
| HLD | High Level Design |
| IAM | Identity and Access Management |
| LLD | Low Level Design |
| MSVX | Multi-Service Virtual Exchange |
| NAT | Network Address Translation |
| RBAC | Role-Based Access Control |
| RDS | Relational Database Service |
| RPO | Recovery Point Objective |
| RTO | Recovery Time Objective |
| S3 | Simple Storage Service |
| SSL | Secure Sockets Layer |
| SSM | Systems Manager |
| TLS | Transport Layer Security |
| VPC | Virtual Private Cloud |

MDEOF

# Step 2: Convert with pandoc using template
echo "Step 2: Converting to DOCX with template..."
pandoc "$TEMP_DIR/hld_formatted.md" \
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
echo "8. Add diagrams from original HLD if required"
echo ""

# Cleanup
rm -rf "$TEMP_DIR"
