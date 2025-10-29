# Emergency Access Procedures - UK MSVX CPS

## Overview
Procedures for granting immediate access to the UK MSVX CPS (Chief Security Officer Shared Services Portal) infrastructure during critical incidents, security events, or business emergencies while maintaining security controls and audit requirements.

## Emergency Access Types

### Break-Glass Access
**Purpose**: Immediate elevated privileges during critical incidents
- **Duration**: Maximum 4 hours
- **Approval**: Security team or designated emergency contact
- **Monitoring**: Real-time alerting and logging
- **Review**: Mandatory within 24 hours

### Expedited Joiner Access
**Purpose**: Rapid onboarding for critical business needs
- **Duration**: Temporary until standard process completion
- **Approval**: Department head and security manager
- **Monitoring**: Enhanced access tracking
- **Review**: Standard JML process within 48 hours

### Incident Response Access
**Purpose**: Security incident investigation and remediation
- **Duration**: Incident duration plus 24 hours
- **Approval**: CISO or security incident commander
- **Monitoring**: Comprehensive activity logging
- **Review**: Post-incident access review

## Emergency Scenarios

### CSO Portal Outages
- **Trigger**: CSO Shared Services Portal unavailability
- **Access Level**: Administrative privileges for affected services (Frontend, Backend, Keystone, RabbitMQ)
- **Approval Process**: On-call manager or incident commander
- **Documentation**: Incident ticket with business justification
- **Access Method**: AWS SSM Session Manager to affected instances

### Identity Service Failures
- **Trigger**: Keystone authentication service failure
- **Access Level**: Keystone administrative access and database connectivity
- **Approval Process**: Security team lead or CISO
- **Documentation**: Security incident report
- **Recovery Actions**: Keystone cluster restart, database connectivity verification

### Database Emergencies
- **Trigger**: RDS MySQL performance issues or connectivity failures
- **Access Level**: Database administrative access and RDS management
- **Approval Process**: Database administrator and security manager
- **Documentation**: Database incident report
- **Recovery Actions**: Performance tuning, failover to standby, backup restoration

### Compliance Emergencies
- **Trigger**: Regulatory deadline or audit requirement
- **Access Level**: Specific compliance-related resources
- **Approval Process**: Compliance officer and legal team
- **Documentation**: Compliance justification memo

### Business Continuity Events
- **Trigger**: Natural disaster, pandemic, or major disruption
- **Access Level**: Essential business operations access
- **Approval Process**: Business continuity team
- **Documentation**: Business continuity activation record

## Emergency Access Process

### Immediate Response (0-15 minutes)
1. **Emergency Declaration**
   - Incident identification
   - Severity assessment
   - Emergency access determination
   - Initial notification

2. **Rapid Approval**
   - Contact emergency approver
   - Verbal authorization (if required)
   - Document approval decision
   - Initiate access provisioning

3. **Access Provisioning**
   - Activate emergency accounts
   - Grant temporary elevated privileges
   - Configure monitoring alerts
   - Notify security team

### Ongoing Management (15 minutes - 4 hours)
1. **Continuous Monitoring**
   - Real-time activity tracking
   - Anomaly detection
   - Regular status updates
   - Escalation procedures

2. **Access Validation**
   - Verify appropriate usage
   - Monitor for abuse
   - Adjust permissions if needed
   - Document all activities

3. **Communication**
   - Regular stakeholder updates
   - Security team notifications
   - Management reporting
   - Audit trail maintenance

### Post-Emergency Review (Within 24 hours)
1. **Access Revocation**
   - Remove emergency privileges
   - Restore standard access levels
   - Deactivate temporary accounts
   - Update access records

2. **Activity Review**
   - Analyze access usage
   - Validate all actions taken
   - Identify any anomalies
   - Document findings

3. **Process Improvement**
   - Lessons learned session
   - Process refinements
   - Training updates
   - Policy adjustments

## Emergency Access Roles

### Emergency Responders
- **CSO Incident Response Team**: Full CSO infrastructure access
- **CSO System Administrators**: EC2 instance and service access
- **Database Administrators**: RDS MySQL emergency access
- **Identity Administrators**: Keystone service emergency access
- **DevOps Engineers**: Terraform and infrastructure emergency access

### Approval Authorities
- **CISO**: Ultimate emergency access authority
- **CSO Security Manager**: Delegated emergency approvals
- **CSO Incident Commander**: Incident-specific approvals
- **CSO Technical Lead**: Service-specific emergency access

### Support Personnel
- **Security Operations Center (SOC)**: 24/7 monitoring
- **IT Help Desk**: Initial triage and escalation
- **Legal Team**: Compliance and regulatory guidance
- **Communications Team**: Stakeholder notifications

## Emergency Access Controls

### Technical Controls
- **AWS SSM Session Manager**: Complete session logging and recording
- **CloudTrail Integration**: Real-time API call monitoring
- **Time Limits**: Automatic session expiration (4-hour maximum)
- **Terraform State Locking**: Prevent concurrent infrastructure changes
- **Cognito Session Management**: Automatic authentication timeout

### Administrative Controls
- **Dual Authorization**: Two-person approval for production access
- **Workspace Isolation**: Separate Terraform workspaces for environments
- **Regular Reviews**: Weekly emergency access audits
- **Training Requirements**: Annual CSO emergency response training

### Physical Controls
- **Secure Locations**: Emergency access from approved facilities
- **Badge Access**: Physical security for emergency operations centers
- **Communication Systems**: Secure channels for emergency coordination

## Emergency Contact Information

### Primary Contacts
- **CISO**: [Contact Information]
- **CSO Security Manager**: [Contact Information]
- **CSO Technical Lead**: [Contact Information]
- **CSO DevOps Lead**: [Contact Information]

### 24/7 Emergency Line
- **CSO Operations Center**: [Phone Number]
- **Emergency Escalation**: [Phone Number]
- **Management Escalation**: [Phone Number]

### Communication Channels
- **Emergency Slack Channel**: #cso-emergency
- **Email Distribution**: cso-emergency@company.com
- **Conference Bridge**: [Conference Details]

## Documentation Requirements

### Emergency Access Log
- Date and time of access grant
- Terraform workspace accessed
- AWS services and instances accessed
- Requestor and approver information
- Business justification
- Access level and duration
- SSM session IDs and activities performed
- Access revocation details

### Incident Documentation
- Emergency access usage report
- CSO service impact assessment
- Business impact analysis
- Keystone service status during incident
- RabbitMQ cluster health during incident
- Database performance impact
- Lessons learned summary
- Process improvement recommendations

## Compliance Considerations

### Regulatory Requirements
- **SOX**: Emergency access controls and documentation
- **PCI DSS**: Secure emergency access procedures
- **HIPAA**: Protected health information access controls
- **GDPR**: Data protection emergency procedures

### Audit Requirements
- Complete audit trail of emergency access
- Regular testing of emergency procedures
- Annual review of emergency access policies
- Compliance reporting for emergency access usage

## Training and Preparedness

### Emergency Response Training
- **Quarterly**: Emergency access procedure drills
- **Annually**: Comprehensive emergency response training
- **As Needed**: Incident-specific training updates

### Tabletop Exercises
- Emergency access scenario testing
- Cross-functional coordination practice
- Process validation and improvement
- Stakeholder communication exercises

## Metrics and Reporting

### Key Performance Indicators
- Emergency access response time
- Approval process duration
- Access revocation compliance
- Post-incident review completion rate

### Regular Reports
- Monthly emergency access usage summary
- Quarterly emergency response metrics
- Annual emergency preparedness assessment
- Compliance audit reports

## UK MSVX CPS Emergency Procedures

### Terraform Emergency Commands
```bash
# Emergency workspace switch
terraform workspace select prod-ha

# Emergency instance replacement
terraform taint module.compute.aws_instance.keystone[0]
terraform apply -auto-approve

# Emergency destroy (extreme cases)
terraform destroy -auto-approve
```

### Service Recovery Commands
```bash
# Keystone service restart
aws ssm send-command --instance-ids i-keystone --document-name "AWS-RunShellScript" --parameters 'commands=["sudo systemctl restart httpd"]'

# RabbitMQ cluster recovery
aws ssm send-command --instance-ids i-rabbitmq --document-name "AWS-RunShellScript" --parameters 'commands=["sudo systemctl restart rabbitmq-server"]'

# Database failover (if Multi-AZ)
aws rds failover-db-cluster --db-cluster-identifier prod-ha-db
```

### Emergency Access Examples
```bash
# Emergency SSM access to production
aws ssm start-session --target i-1234567890abcdef0

# Emergency Cognito user creation
aws cognito-idp admin-create-user --user-pool-id us-west-2_XXXXXXXXX --username emergency-user

# Emergency Keystone token
source /home/ecs/env.sh && openstack token issue
```

## Related Documentation
- [JML Processes](./jml-processes/README.md)
- [User Account Management](./user-account-management.md)
- [AWS Infrastructure Access](./aws-infrastructure-access.md)
- [UK MSVX CPS Architecture](../../readme/HLD.md)
- [Terraform Deployment Guide](../../readme/README.md)