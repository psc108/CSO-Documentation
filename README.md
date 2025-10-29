# UK MSVX CPS Documentation

## Overview
This repository contains comprehensive documentation for the UK MSVX CPS (Chief Security Officer Shared Services Portal) project, focusing on AWS infrastructure access management, identity services, and security procedures for the multi-tier CSO application platform.

## Documentation Structure

### Access Management
- [UK MSVX CPS Access Management Overview](./access-management/README.md)
- [Joiner, Mover, Leaver (JML) Processes](./access-management/jml-processes/README.md)
- [User Account Management](./access-management/user-account-management.md)
- [UK MSVX CPS Infrastructure Access](./access-management/aws-infrastructure-access.md)

### Quick Links
- [Emergency Access Procedures](./access-management/emergency-access.md)
- [Compliance and Audit](./access-management/compliance-audit.md)
- [Security Policies](./security-policies/README.md)

## Getting Started
1. Review the [UK MSVX CPS Access Management Overview](./access-management/README.md)
2. Familiarize yourself with [JML Processes](./access-management/jml-processes/README.md) for the CSO infrastructure
3. Understand [UK MSVX CPS Infrastructure Access](./access-management/aws-infrastructure-access.md) requirements
4. Review the [UK MSVX CPS Architecture](../uk-msvx-cps-tf-modular/readme/HLD.md) for technical context
5. Consult the [Terraform Deployment Guide](../uk-msvx-cps-tf-modular/readme/README.md) for implementation details

## UK MSVX CPS Project Context

### Infrastructure Components
- **Frontend Servers**: CSO Management UI and Portal UI (port 8102)
- **Backend Servers**: Core business logic and API endpoints
- **Keystone Servers**: OpenStack identity service (port 5000)
- **RabbitMQ Cluster**: Message queuing with management interface
- **Jump Server**: Administrative access and deployment coordination
- **RDS MySQL**: Multi-AZ database with automated backups
- **Application Load Balancer**: SSL termination and path-based routing

### Environment Types
- **Development**: Single-node deployment with direct access
- **Staging**: HA deployment with Cognito authentication
- **Production**: Full HA with Multi-AZ and enhanced security

### Key Technologies
- **Terraform**: Infrastructure as Code with modular architecture
- **AWS Cognito**: Load balancer authentication for HA environments
- **OpenStack Keystone**: Service-level identity and authentication
- **AWS SSM Session Manager**: Secure administrative access (no SSH)
- **AWS Secrets Manager**: Centralized password and credential management

## Contributing
Please follow the documentation standards and review processes outlined in each section. All documentation should reflect the specific UK MSVX CPS infrastructure and services.