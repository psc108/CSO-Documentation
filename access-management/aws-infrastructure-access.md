# UK MSVX CPS Infrastructure Access Management

## Overview
Comprehensive framework for managing access to the UK MSVX CPS (Chief Security Officer Shared Services Portal) infrastructure, including AWS resources, Keystone identity services, and multi-tier application access.

## Access Architecture

### UK MSVX CPS Environment Strategy
- **Production Environment**: Live CSO portal with Multi-AZ deployment
- **Staging Environment**: Pre-production testing with HA configuration
- **Development Environment**: Single-node development and testing

### Multi-Tier Access Model
```
AWS Cognito (HA) → Application Load Balancer → CSO Services → Keystone Authentication → Backend Resources
```

### Service Architecture
- **Frontend Tier**: Management UI and Portal UI (port 8102)
- **Application Tier**: Backend services and API endpoints
- **Identity Tier**: OpenStack Keystone service (port 5000)
- **Message Tier**: RabbitMQ cluster with management interface
- **Data Tier**: RDS MySQL Multi-AZ with automated backups

## Permission Framework

### Role-Based Access Control (RBAC)

#### Administrative Roles
- **CSO Infrastructure Administrator**: Full Terraform and AWS access
- **CSO Application Administrator**: CSO portal and Keystone management
- **Database Administrator**: RDS MySQL and backup management
- **Security Administrator**: IAM, Cognito, and security services

#### Developer Roles
- **Senior CSO Developer**: Full development environment access
- **CSO Developer**: Standard development and staging access
- **Frontend Developer**: UI development and testing access
- **Backend Developer**: API and service development access

#### Operations Roles
- **CSO DevOps Engineer**: Terraform deployment and automation
- **CSO Site Reliability Engineer**: Monitoring and incident response
- **CSO Support Engineer**: Read-only troubleshooting access
- **Identity Administrator**: Keystone user and project management

### Service-Specific Access

#### UK MSVX CPS Compute Services
- **EC2 Instances**: Frontend, Backend, Keystone, RabbitMQ, Jump servers
- **Application Load Balancer**: SSL termination and path-based routing
- **Auto Scaling**: Future enhancement for dynamic scaling
- **ECS/EKS**: Future containerization migration

#### UK MSVX CPS Storage Services
- **S3**: Installation packages, configuration files, backups
- **EFS**: Shared file system for SSL certificates and scripts
- **EBS**: Encrypted volumes for all EC2 instances
- **RDS Storage**: Auto-scaling MySQL storage (50GB-1TB)

#### UK MSVX CPS Database Services
- **RDS MySQL**: Multi-AZ deployment with automated backups
- **Secrets Manager**: Database and service password management
- **Performance Insights**: Database performance monitoring
- **Backup Management**: 30-day retention for production

#### Security Services
- **IAM**: User and role management (restricted)
- **KMS**: Key management and encryption operations
- **Secrets Manager**: Secret storage and rotation
- **Certificate Manager**: SSL/TLS certificate management

## Environment-Specific Access

### Production Environment (prod-ha)
- **Access Requirements**:
  - Manager approval required
  - AWS Cognito MFA mandatory
  - Time-limited access (4-hour sessions)
  - Change management process
  - Comprehensive audit logging

- **Infrastructure Configuration**:
  - Multi-AZ deployment across eu-west-2a and eu-west-2c
  - Application Load Balancer with SSL termination
  - RDS Multi-AZ with 30-day backup retention
  - Production instance sizing (c5.4xlarge backend, c5.2xlarge frontend)

- **Permitted Actions**:
  - Read-only access via SSM Session Manager
  - Emergency break-glass procedures
  - Approved maintenance windows
  - Incident response activities

### Staging Environment (staging)
- **Access Requirements**:
  - Team lead approval
  - AWS Cognito authentication
  - Standard session duration
  - Change notification process

- **Infrastructure Configuration**:
  - HA deployment with development instance sizing
  - Full Cognito authentication flow
  - 7-day backup retention
  - Complete service integration testing

- **Permitted Actions**:
  - Full testing capabilities
  - Configuration changes
  - Data refresh operations
  - Performance testing

### Development Environment (dev)
- **Access Requirements**:
  - Self-service provisioning via Terraform
  - MFA recommended
  - Extended session duration
  - Minimal approval process

- **Infrastructure Configuration**:
  - Single-node deployment in single AZ
  - Direct EIP access (no load balancer)
  - Development instance sizing (t2.xlarge)
  - Basic backup retention

- **Permitted Actions**:
  - Full Terraform workspace management
  - Resource creation/deletion
  - Service experimentation
  - Development and testing

## Access Control Mechanisms

### UK MSVX CPS IAM Policies

#### CSO Infrastructure Permission Boundary
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "rds:*",
        "efs:*",
        "s3:*",
        "elbv2:*",
        "cognito-idp:*",
        "secretsmanager:*",
        "ssm:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": ["eu-west-2"]
        }
      }
    }
  ]
}
```

#### Resource-Based Policies
- S3 bucket policies
- KMS key policies
- Lambda resource policies
- SNS topic policies

### Terraform Workspace Policies
- Environment-specific resource isolation
- Workspace-based access controls
- State file security and versioning
- Resource tagging enforcement

### UK MSVX CPS Config Rules
- EC2 instance compliance monitoring
- RDS encryption and backup validation
- EFS encryption verification
- Security group compliance checking

## Access Provisioning

### Standard Provisioning Process
1. **Access Request**
   - Business justification
   - Required permissions
   - Duration of access
   - Approval workflow

2. **Security Review**
   - Risk assessment
   - Compliance validation
   - Alternative solutions
   - Approval decision

3. **Implementation**
   - Role assignment
   - Policy attachment
   - Testing validation
   - Documentation update

### Just-In-Time (JIT) Access
- Temporary privilege elevation
- Time-bound access grants
- Automated expiration
- Activity monitoring

### Break-Glass Access
- Emergency access procedures
- Immediate privilege escalation
- Enhanced monitoring
- Post-incident review

## Monitoring and Compliance

### UK MSVX CPS Access Monitoring
- **AWS CloudTrail**: API call logging and audit trails
- **AWS SSM Session Manager**: Administrative access logging
- **Application Load Balancer**: Access logs and metrics
- **Keystone Audit Logs**: Identity service access tracking
- **RabbitMQ Management Logs**: Message broker access monitoring

### Key Metrics
- SSM session usage and duration
- Cognito authentication success/failure rates
- Keystone token issuance and validation
- Application Load Balancer health check status
- RDS connection and query performance

### Compliance Reporting
- SOX compliance reports
- PCI DSS access reviews
- GDPR data access logs
- Industry-specific requirements

## Security Best Practices

### Principle of Least Privilege
- Minimal necessary permissions
- Regular access reviews
- Automated access removal
- Permission right-sizing

### Defense in Depth
- Multiple security layers
- Network segmentation
- Encryption at rest and in transit
- Comprehensive monitoring

### Zero Trust Architecture
- Verify every access request
- Continuous authentication
- Micro-segmentation
- Behavioral analytics

## Automation and Tools

### UK MSVX CPS Infrastructure as Code
- **Terraform Modular Architecture**: Networking, Security, Compute, Storage, Database, DNS modules
- **Environment Configuration**: YAML-based environment definitions (dev, staging, prod-ha)
- **Automated Deployment**: PowerShell and Bash deployment scripts
- **State Management**: S3 backend with state locking

### UK MSVX CPS Access Management Tools
- **AWS SSM Session Manager**: Secure administrative access
- **AWS Cognito**: Load balancer authentication
- **OpenStack Keystone**: Service authentication and authorization
- **AWS Secrets Manager**: Centralized password management
- **Terraform Workspaces**: Environment isolation

### UK MSVX CPS Monitoring and Alerting
- **CloudWatch**: Infrastructure metrics and application logs
- **RDS Performance Insights**: Database performance monitoring
- **Application Load Balancer Metrics**: Request and response monitoring
- **Keystone Service Monitoring**: Identity service health checks
- **RabbitMQ Management Interface**: Message broker monitoring

## Incident Response

### Access-Related Incidents
- Unauthorized access attempts
- Privilege escalation events
- Compromised credentials
- Policy violations

### Response Procedures
1. Immediate access revocation
2. Incident containment
3. Forensic investigation
4. Remediation actions
5. Lessons learned

## Training and Awareness

### Required Training
- AWS security fundamentals
- Company security policies
- Incident response procedures
- Compliance requirements

### Ongoing Education
- Security awareness campaigns
- Technology updates
- Best practice sharing
- Certification programs

## UK MSVX CPS Specific Access Patterns

### Terraform Workspace Access
```bash
# Switch to production workspace
terraform workspace select prod-ha

# Deploy with environment-specific configuration
.\deploy.ps1 -AutoApprove

# Access production resources via SSM
aws ssm start-session --target i-1234567890abcdef0
```

### Keystone Service Access
```bash
# Authenticate with Keystone
source /home/ecs/env.sh
openstack token issue

# Manage users and projects
openstack user list
openstack project list
```

### RabbitMQ Management Access
```bash
# Access RabbitMQ management interface
https://alb-dns-name/admin/

# API access for automation
curl -u admin:password https://rabbitmq-server:15671/api/overview
```

## Related Documentation
- [JML Processes](./jml-processes/README.md)
- [User Account Management](./user-account-management.md)
- [Emergency Access Procedures](./emergency-access.md)
- [Compliance and Audit](./compliance-audit.md)
- [UK MSVX CPS Architecture](../../readme/HLD.md)
- [Terraform Deployment Guide](../../readme/README.md)