# Joiner, Mover, Leaver (JML) Processes - UK MSVX CPS

## Overview
The JML processes ensure secure and efficient management of user access throughout the employee lifecycle in the UK MSVX CPS (Chief Security Officer Shared Services Portal) infrastructure and related systems.

## Process Components

### 1. Joiner Process
**Objective**: Provision appropriate access for new employees or contractors

#### Pre-boarding Requirements
- [ ] Employee/contractor information received from HR
- [ ] Role and department identification
- [ ] Manager approval for access requirements
- [ ] Security clearance verification (if applicable)

#### UK MSVX CPS Account Provisioning
- [ ] Create AWS IAM user account with SSM access
- [ ] Assign to appropriate IAM groups based on role
- [ ] Configure AWS Cognito user (for HA environments)
- [ ] Create Keystone user account and project assignment
- [ ] Set up CSO application user profile
- [ ] Document account creation in access management system

#### Access Assignment
- [ ] Determine required CSO services (Frontend, Backend, Keystone, RabbitMQ)
- [ ] Apply environment-specific access policies (dev/staging/prod)
- [ ] Configure Keystone project and role assignments
- [ ] Set up RabbitMQ user and vhost permissions
- [ ] Configure database access permissions (if required)
- [ ] Validate access permissions across all service layers

### 2. Mover Process
**Objective**: Modify access when employees change roles or departments

#### Role Change Assessment
- [ ] Identify current access permissions
- [ ] Determine new role requirements
- [ ] Manager approval for access changes
- [ ] Security impact assessment

#### Access Modification
- [ ] Remove unnecessary AWS IAM permissions
- [ ] Update Keystone project and role assignments
- [ ] Modify CSO application role permissions
- [ ] Update RabbitMQ user permissions and vhost access
- [ ] Adjust environment-specific access (dev/staging/prod)
- [ ] Update Cognito user group memberships (HA environments)
- [ ] Update documentation and records

#### Validation
- [ ] Test new access permissions
- [ ] Confirm removal of old permissions
- [ ] Update access management system
- [ ] Notify relevant stakeholders

### 3. Leaver Process
**Objective**: Securely remove access for departing employees

#### Pre-departure Planning
- [ ] HR notification of departure date
- [ ] Identify all AWS accounts and access
- [ ] Plan knowledge transfer requirements
- [ ] Schedule access removal timeline

#### Access Removal
- [ ] Disable AWS IAM user account
- [ ] Remove from all IAM groups and policies
- [ ] Disable/delete AWS Cognito user account
- [ ] Disable Keystone user account and revoke tokens
- [ ] Remove CSO application user profile
- [ ] Delete RabbitMQ user and associated permissions
- [ ] Revoke database access permissions
- [ ] Remove API keys and access tokens
- [ ] Clean up EFS and S3 access permissions

#### Post-departure Cleanup
- [ ] Archive account information
- [ ] Update documentation
- [ ] Conduct access removal verification
- [ ] Generate departure access report

## Process Workflows

### Joiner Workflow
```
HR Request → Security Review → Manager Approval → Account Creation → Access Assignment → Validation → Documentation
```

### Mover Workflow
```
Role Change Request → Current Access Review → New Requirements Analysis → Access Modification → Validation → Documentation Update
```

### Leaver Workflow
```
Departure Notification → Access Inventory → Removal Planning → Account Deactivation → Resource Transfer → Final Cleanup → Audit Report
```

## Automation and Tools
- **AWS IAM Access Analyzer**: Identify unused access
- **AWS CloudTrail**: Audit access usage
- **AWS Config**: Monitor configuration changes
- **AWS SSM Session Manager**: Secure administrative access
- **Terraform Workspaces**: Environment-specific provisioning
- **Keystone API**: Automated identity management
- **RabbitMQ Management API**: User and permission management
- **Custom Scripts**: Automated provisioning/deprovisioning
- **ITSM Integration**: Workflow management

## Compliance and Audit
- Monthly access reviews
- Quarterly JML process audits
- Annual access certification
- Compliance reporting for SOX, PCI, etc.

## UK MSVX CPS Specific Considerations

### Environment-Specific Processes
- **Development Environment**: Simplified access with direct EIP access
- **Staging Environment**: HA deployment with Cognito authentication
- **Production Environment**: Full security controls with Multi-AZ deployment

### Service-Specific Access Management
- **Keystone Identity Service**: OpenStack user and project management
- **RabbitMQ Cluster**: Message broker user and vhost permissions
- **CSO Application**: Role-based application access controls
- **Database Access**: RDS MySQL with Secrets Manager integration

### Terraform Workspace Management
- **Workspace Creation**: Environment isolation and resource naming
- **State Management**: Secure Terraform state in S3 backend
- **Resource Tagging**: Consistent tagging for access tracking

## Emergency Procedures
- [Emergency Access Procedures](../emergency-access.md)
- Expedited joiner process for critical CSO roles
- Emergency access revocation procedures
- Break-glass access to production environments

## Related Documentation
- [User Account Management](../user-account-management.md)
- [AWS Infrastructure Access](../aws-infrastructure-access.md)
- [Compliance and Audit](../compliance-audit.md)
- [UK MSVX CPS Architecture](../../readme/HLD.md)
- [Terraform Deployment Guide](../../readme/README.md)