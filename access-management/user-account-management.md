# User Account Management - UK MSVX CPS

## Overview
Comprehensive guidelines for managing user accounts across the UK MSVX CPS infrastructure, including AWS IAM, Keystone identity service, and CSO application accounts.

## Account Types

### AWS IAM Users
- **Purpose**: Infrastructure-level access for administrators and developers
- **Naming Convention**: `firstname.lastname` or `employee.id`
- **Requirements**: MFA enabled, SSM access permissions
- **Lifecycle**: Managed through JML processes
- **Access Method**: AWS SSM Session Manager (no SSH keys)

### AWS Cognito Users (HA Environments)
- **Purpose**: Load balancer authentication for HA deployments
- **Naming Convention**: `username` (e.g., `csoadmin`)
- **Requirements**: Strong password policy, MFA support
- **Integration**: OIDC authentication with ALB

### Keystone Users
- **Purpose**: OpenStack identity service for API authentication
- **Naming Convention**: `username` (e.g., `admin`, `service_user`)
- **Requirements**: Project assignment, role-based permissions
- **Authentication**: Token-based API access

### CSO Application Users
- **Purpose**: End-user access to CSO Shared Services Portal
- **Naming Convention**: `username` (e.g., `systemadmin`)
- **Requirements**: Role-based access control within application
- **Integration**: Keystone authentication backend

### Service Accounts
- **Purpose**: Inter-service communication and automation
- **Types**:
  - RabbitMQ service users (`ssp_user`)
  - Database service accounts
  - API service accounts
- **Requirements**: Programmatic access only, minimal permissions
- **Security**: Automated password rotation via Secrets Manager

## Account Standards

### Password Policy
- Minimum 14 characters
- Mix of uppercase, lowercase, numbers, symbols
- No dictionary words or personal information
- 90-day expiration (where applicable)
- No password reuse (last 12 passwords)

### Multi-Factor Authentication (MFA)
- **AWS IAM**: Required for all human users
- **AWS Cognito**: Configurable MFA for HA environments
- **Keystone**: Token-based authentication (no MFA)
- **CSO Application**: Application-level authentication
- Supported methods:
  - Hardware tokens (preferred)
  - Virtual MFA apps (Google Authenticator, Authy)
  - SMS (emergency backup only)

### Access Keys
- Maximum 2 active keys per user
- 90-day rotation requirement
- Secure storage in AWS Secrets Manager
- Regular usage monitoring

## Account Provisioning

### Standard Process
1. **Request Validation**
   - HR verification
   - Manager approval
   - Role-based access determination

2. **Account Creation**
   - Generate secure temporary password
   - Assign to appropriate IAM groups
   - Configure MFA requirements
   - Set account tags for tracking

3. **Initial Setup**
   - Force password reset on first login
   - MFA device registration
   - Access validation testing
   - Documentation update

### Automated Provisioning
- Integration with HR systems
- SCIM protocol support
- Automated group assignment
- Compliance validation

## Account Maintenance

### Regular Reviews
- **Monthly**: Active account verification
- **Quarterly**: Permission reviews
- **Annually**: Comprehensive access certification

### Monitoring and Alerts
- Unusual login patterns
- Failed authentication attempts
- Privilege escalation activities
- Dormant account identification

### Account Updates
- Role changes through Mover process
- Permission modifications
- Contact information updates
- Security attribute changes

## Account Deactivation

### Immediate Deactivation Triggers
- Employee termination
- Security incident involvement
- Policy violations
- Extended leave (>90 days)

### Deactivation Process
1. Disable account login
2. Revoke active sessions
3. Remove from groups
4. Archive account data
5. Update documentation

## Compliance Requirements

### Audit Trail
- All account changes logged
- Access usage tracking
- Regular compliance reports
- Retention per policy requirements

### Segregation of Duties
- Account creation vs. permission assignment
- Approval workflows
- Independent validation
- Audit oversight

## Emergency Procedures

### Emergency Account Creation
- Expedited approval process
- Temporary elevated permissions
- Enhanced monitoring
- Mandatory review within 24 hours

### Account Recovery
- Identity verification procedures
- MFA reset processes
- Temporary access provisions
- Security validation requirements

## Tools and Integration

### AWS Services
- AWS IAM (infrastructure access)
- AWS Cognito (load balancer authentication)
- AWS Secrets Manager (password management)
- AWS SSM Session Manager (secure access)
- AWS CloudTrail (audit logging)

### UK MSVX CPS Services
- OpenStack Keystone (identity service)
- RabbitMQ Management API (message broker users)
- CSO Application (end-user management)
- RDS MySQL (database authentication)

### Third-party Tools
- Terraform (infrastructure as code)
- ITSM systems (ServiceNow, Jira)
- Monitoring tools (CloudWatch, application logs)
- Compliance platforms

## Metrics and Reporting

### Key Performance Indicators
- Account provisioning time
- Deactivation compliance rate
- MFA adoption percentage
- Access review completion rate

### Regular Reports
- Monthly account status report
- Quarterly access review summary
- Annual compliance certification
- Security incident correlation

## UK MSVX CPS Specific Account Management

### Environment-Specific Considerations
- **Development**: Single-node with simplified access controls
- **Staging**: HA deployment with Cognito authentication
- **Production**: Full security controls with Multi-AZ deployment

### Service Integration
- **Keystone-CSO Integration**: Keystone provides authentication for CSO application
- **RabbitMQ User Management**: Service users for message queuing
- **Database Access**: RDS MySQL with managed passwords
- **EFS Access**: Shared file system permissions for configuration

### Terraform Workspace Integration
- **Environment Isolation**: Separate user contexts per workspace
- **Resource Tagging**: Consistent tagging for user tracking
- **State Management**: Secure access to Terraform state

## Related Documentation
- [JML Processes](./jml-processes/README.md)
- [AWS Infrastructure Access](./aws-infrastructure-access.md)
- [Emergency Access Procedures](./emergency-access.md)
- [Compliance and Audit](./compliance-audit.md)
- [UK MSVX CPS Architecture](../../readme/HLD.md)
- [Terraform Deployment Guide](../../readme/README.md)