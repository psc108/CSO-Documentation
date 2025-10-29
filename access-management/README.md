# UK MSVX CPS Access Management

## Overview
This section covers comprehensive access management for the UK MSVX CPS (Chief Security Officer Shared Services Portal) infrastructure, including AWS IAM, OpenStack Keystone identity services, and multi-tier application access controls.

## Infrastructure Components

### 1. CSO Shared Services Portal Architecture
- **Frontend Servers**: Management UI and Portal UI (port 8102)
- **Backend Servers**: Core business logic and API endpoints
- **Keystone Servers**: OpenStack identity service (port 5000)
- **RabbitMQ Cluster**: Message queuing and inter-service communication
- **Jump Server**: Administrative access and deployment coordination
- **RDS MySQL**: Multi-AZ database with automated backups

### 2. Identity and Access Management Layers
- **AWS IAM**: Infrastructure-level access control
- **AWS Cognito**: Load balancer authentication for HA deployments
- **OpenStack Keystone**: Service-level identity and authentication
- **CSO Application**: Application-level user management

### 3. Access Control Framework
- **Multi-Layer Authentication**: AWS Cognito → CSO Application → Keystone
- **Role-Based Access Control (RBAC)**: CSO roles and Keystone projects
- **Service-to-Service Authentication**: Keystone tokens for API access
- **Administrative Access**: SSM Session Manager (no SSH keys required)

## Process Documentation
- [Joiner, Mover, Leaver Processes](./jml-processes/README.md)
- [User Account Management](./user-account-management.md)
- [AWS Infrastructure Access](./aws-infrastructure-access.md)
- [Emergency Access Procedures](./emergency-access.md)
- [Compliance and Audit](./compliance-audit.md)

## UK MSVX CPS Specific Access Patterns

### Environment-Based Access
- **Development**: Single-node deployment with direct EIP access
- **Staging**: HA deployment with Cognito authentication
- **Production**: Full HA with Multi-AZ, enhanced monitoring

### Service Access Methods
- **Administrative Access**: AWS SSM Session Manager (no SSH required)
- **Application Access**: HTTPS via Application Load Balancer
- **API Access**: Direct service endpoints with Keystone authentication
- **Database Access**: RDS with AWS Secrets Manager integration

### Security Standards
- **AWS Cognito MFA**: Required for HA deployment access
- **Keystone Authentication**: Service-to-service API access
- **SSL/TLS Encryption**: All communications encrypted
- **Automated Certificate Management**: Self-signed with ACM integration
- **Comprehensive Audit Logging**: CloudTrail, SSM sessions, application logs

## Related Documentation
- [Security Policies](../security-policies/README.md)
- [UK MSVX CPS Architecture](../../readme/HLD.md)
- [Terraform Deployment Guide](../../readme/README.md)