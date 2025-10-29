# Backup and Recovery Plan - UK MSVX CPS Infrastructure

## 1. Executive Summary

### 1.1 Purpose
This document provides comprehensive backup and recovery procedures for the UK MSVX CPS (Chief Security Officer Shared Services Portal) infrastructure, ensuring business continuity and data protection across all system components.

### 1.2 Recovery Objectives
```yaml
Recovery Time Objectives (RTO):
  Critical Systems:    4 hours
  Non-Critical:        24 hours
  Full Environment:    8 hours

Recovery Point Objectives (RPO):
  Database:           1 hour
  Configuration:      4 hours
  Application Data:   24 hours
```

### 1.3 Backup Strategy Overview
```
┌─────────────────────────────────────────────────────────────────┐
│                    BACKUP ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────────┤
│  Infrastructure (Terraform)  →  Git + S3 State                 │
│  Database (RDS MySQL)        →  Automated Backups + Snapshots  │
│  File Systems (EFS)          →  AWS Backup + Cross-Region      │
│  Configuration (S3)          →  Versioning + Cross-Region      │
│  Secrets (Secrets Manager)   →  Automatic Replication          │
│  Application Data            →  EFS Snapshots + S3 Export      │
└─────────────────────────────────────────────────────────────────┘
```

## 2. Infrastructure Backup Strategy

### 2.1 Terraform State Management

#### 2.1.1 Current State Backend Configuration
```hcl
terraform {
  backend "s3" {
    bucket = "001a2b3c"  # Production bucket
    key    = "terraform.tfstate"
    region = "eu-west-2"
  }
}
```

#### 2.1.2 State Backup Procedures
```yaml
Automated Backups:
  S3 Versioning: Enabled on state bucket
  Retention: 90 days for all versions
  Cross-Region: Replicated to eu-west-1
  
Manual Backups:
  Frequency: Before major changes
  Location: Local backup directory
  Command: terraform state pull > backup-$(date +%Y%m%d-%H%M%S).tfstate
```

#### 2.1.3 State Recovery Procedures
```bash
# Emergency state recovery
terraform state pull > current-state-backup.tfstate

# Restore from backup
terraform state push backup-20241220-143022.tfstate

# Verify state integrity
terraform plan -detailed-exitcode
```

### 2.2 Infrastructure Code Backup

#### 2.2.1 Git Repository Backup
```yaml
Primary Repository: Git-based version control
Backup Strategy:
  - Multiple remote repositories
  - Daily automated backups
  - Branch protection rules
  - Tag-based releases

Backup Locations:
  - Primary: Company Git server
  - Secondary: GitHub/GitLab mirror
  - Local: Developer workstations
```

#### 2.2.2 Project Directory Backup
```powershell
# Automated project backup script
.\backup-uk-msvx-cps-tf-modular.ps1 `
  "C:\Users\pscott32\IdeaProjects\uk-msvx-cps-tf-modular" `
  "D:\Backups\uk-msvx-cps-tf-modular-$(Get-Date -Format 'yyyy-MM-dd')"

# Restore from backup
.\backup-uk-msvx-cps-tf-modular.ps1 `
  "D:\Backups\uk-msvx-cps-tf-modular-2024-12-20" `
  "C:\Users\pscott32\IdeaProjects\uk-msvx-cps-tf-modular" `
  -Restore
```

## 3. Database Backup and Recovery

### 3.1 RDS MySQL Backup Configuration

#### 3.1.1 Automated Backup Settings
```hcl
resource "aws_db_instance" "main" {
  backup_retention_period = var.prod ? 30 : 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  skip_final_snapshot    = !var.prod
  final_snapshot_identifier = var.prod ? "${var.environment}-db-final-snapshot" : null
  copy_tags_to_snapshot  = true
}
```

#### 3.1.2 Backup Schedule
```yaml
Production Environment:
  Automated Backups: Daily at 03:00 UTC
  Retention Period: 30 days
  Point-in-Time Recovery: Available
  Final Snapshot: Created on deletion
  
Development Environment:
  Automated Backups: Daily at 03:00 UTC
  Retention Period: 7 days
  Point-in-Time Recovery: Available
  Final Snapshot: Skipped
```

#### 3.1.3 Manual Snapshot Procedures
```bash
# Create manual snapshot
aws rds create-db-snapshot \
  --db-instance-identifier prod-ha-db \
  --db-snapshot-identifier prod-ha-db-manual-$(date +%Y%m%d-%H%M%S)

# List available snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier prod-ha-db \
  --snapshot-type manual

# Copy snapshot to another region
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier prod-ha-db-manual-20241220-143022 \
  --target-db-snapshot-identifier prod-ha-db-dr-20241220-143022 \
  --source-region eu-west-2 \
  --region eu-west-1
```

### 3.2 Database Recovery Procedures

#### 3.2.1 Point-in-Time Recovery
```bash
# Restore to specific point in time
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier prod-ha-db \
  --target-db-instance-identifier prod-ha-db-restored \
  --restore-time 2024-12-20T14:30:00.000Z \
  --subnet-group-name prod-ha-rds-subnets \
  --vpc-security-group-ids sg-12345678

# Monitor restoration progress
aws rds describe-db-instances \
  --db-instance-identifier prod-ha-db-restored \
  --query 'DBInstances[0].DBInstanceStatus'
```

#### 3.2.2 Snapshot Recovery
```bash
# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier prod-ha-db-restored \
  --db-snapshot-identifier prod-ha-db-manual-20241220-143022 \
  --db-instance-class db.c5.4xlarge \
  --subnet-group-name prod-ha-rds-subnets \
  --vpc-security-group-ids sg-12345678

# Update application configuration
terraform apply -var="restore_from_snapshot=true"
```

## 4. File System Backup and Recovery

### 4.1 EFS Backup Strategy

#### 4.1.1 AWS Backup Configuration
```hcl
resource "aws_backup_vault" "cso_backup" {
  name        = "${var.environment}-cso-backup-vault"
  kms_key_arn = aws_kms_key.backup.arn
}

resource "aws_backup_plan" "cso_backup" {
  name = "${var.environment}-cso-backup-plan"
  
  rule {
    rule_name         = "daily_backup"
    target_vault_name = aws_backup_vault.cso_backup.name
    schedule          = "cron(0 5 ? * * *)"  # 5 AM UTC daily
    
    lifecycle {
      cold_storage_after = 30
      delete_after       = 365
    }
    
    recovery_point_tags = {
      Environment = var.environment
      BackupType  = "automated"
    }
  }
}
```

#### 4.1.2 EFS Backup Schedule
```yaml
Scripts EFS (/opt/scripts):
  Frequency: Daily at 05:00 UTC
  Retention: 365 days
  Cold Storage: After 30 days
  Cross-Region: Replicated to eu-west-1
  
SSL Certificates EFS (/opt/ssl-certs):
  Frequency: Daily at 05:00 UTC
  Retention: 365 days
  Cold Storage: After 30 days
  Cross-Region: Replicated to eu-west-1
```

#### 4.1.3 Manual EFS Backup
```bash
# Create manual EFS backup
aws backup start-backup-job \
  --backup-vault-name prod-ha-cso-backup-vault \
  --resource-arn arn:aws:elasticfilesystem:eu-west-2:123456789012:file-system/fs-12345678 \
  --iam-role-arn arn:aws:iam::123456789012:role/aws-backup-service-role

# Monitor backup progress
aws backup describe-backup-job --backup-job-id backup-job-12345678
```

### 4.2 S3 Backup Strategy

#### 4.2.1 S3 Versioning and Lifecycle
```hcl
resource "aws_s3_bucket_versioning" "cso_files" {
  bucket = aws_s3_bucket.cso_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cso_files" {
  bucket = aws_s3_bucket.cso_files.id
  
  rule {
    id     = "backup_lifecycle"
    status = "Enabled"
    
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }
    
    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }
    
    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}
```

#### 4.2.2 Cross-Region Replication
```hcl
resource "aws_s3_bucket_replication_configuration" "cso_files" {
  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.cso_files.id
  
  rule {
    id     = "replicate_all"
    status = "Enabled"
    
    destination {
      bucket        = aws_s3_bucket.cso_files_replica.arn
      storage_class = "STANDARD_IA"
    }
  }
}
```

### 4.3 File System Recovery Procedures

#### 4.3.1 EFS Recovery from Backup
```bash
# List available EFS backups
aws backup list-recovery-points \
  --backup-vault-name prod-ha-cso-backup-vault \
  --by-resource-type EFS

# Restore EFS from backup
aws backup start-restore-job \
  --recovery-point-arn arn:aws:backup:eu-west-2:123456789012:recovery-point:backup-vault-12345678 \
  --metadata file-system-id=fs-87654321,Encrypted=true,PerformanceMode=generalPurpose \
  --iam-role-arn arn:aws:iam::123456789012:role/aws-backup-service-role

# Monitor restore progress
aws backup describe-restore-job --restore-job-id restore-job-12345678
```

#### 4.3.2 S3 File Recovery
```bash
# List S3 object versions
aws s3api list-object-versions \
  --bucket prod-ha-cso-files \
  --prefix installation-package

# Restore specific version
aws s3api copy-object \
  --copy-source prod-ha-cso-files/installation-package.jar?versionId=version-12345678 \
  --bucket prod-ha-cso-files \
  --key installation-package.jar

# Sync from replica bucket
aws s3 sync s3://prod-ha-cso-files-replica s3://prod-ha-cso-files --delete
```

## 5. Configuration and Secrets Backup

### 5.1 AWS Secrets Manager Backup

#### 5.1.1 Secrets Replication Configuration
```hcl
resource "aws_secretsmanager_secret" "service_passwords" {
  name                    = "env-${local.ws}-passwords-v2"
  recovery_window_in_days = 0
  kms_key_id             = aws_kms_key.secrets.arn
  
  replica {
    region = "eu-west-1"
    kms_key_id = aws_kms_key.secrets_replica.arn
  }
}
```

#### 5.1.2 Manual Secrets Backup
```bash
# Export secrets to encrypted file
aws secretsmanager get-secret-value \
  --secret-id env-prod-ha-passwords-v2 \
  --query SecretString \
  --output text > secrets-backup-$(date +%Y%m%d).json

# Encrypt backup file
gpg --symmetric --cipher-algo AES256 secrets-backup-$(date +%Y%m%d).json

# Store in secure location
aws s3 cp secrets-backup-$(date +%Y%m%d).json.gpg \
  s3://secure-backup-bucket/secrets/ \
  --sse aws:kms \
  --sse-kms-key-id alias/backup-encryption
```

### 5.2 Environment Configuration Backup

#### 5.2.1 Environment Files Backup
```yaml
Configuration Files:
  - env.dev.yaml
  - env.staging.yaml  
  - env.prod-ha.yaml
  - locals.tf
  - variables.tf

Backup Strategy:
  Primary: Git version control
  Secondary: S3 versioned storage
  Tertiary: Local backup copies
```

#### 5.2.2 SSL Certificates Backup
```bash
# Backup SSL certificates from EFS
aws ssm start-session --target i-jump-server-id

# On jump server
sudo tar -czf ssl-certs-backup-$(date +%Y%m%d).tar.gz -C /opt/ssl-certs .

# Upload to S3
aws s3 cp ssl-certs-backup-$(date +%Y%m%d).tar.gz \
  s3://prod-ha-cso-files/backups/ssl-certificates/ \
  --sse aws:kms
```

## 6. Application Data Backup

### 6.1 Service-Specific Data Backup

#### 6.1.1 Keystone Configuration Backup
```bash
# Backup Keystone configuration
sudo tar -czf keystone-config-backup-$(date +%Y%m%d).tar.gz \
  /etc/keystone/ \
  /opt/keystone-venv/ \
  /var/log/httpd/keystone.log

# Backup fernet keys
sudo cp -r /etc/keystone/fernet-keys-shared \
  /opt/scripts/backups/keystone-fernet-$(date +%Y%m%d)
```

#### 6.1.2 RabbitMQ Configuration Backup
```bash
# Export RabbitMQ definitions
sudo rabbitmqctl export_definitions \
  /opt/scripts/backups/rabbitmq-definitions-$(date +%Y%m%d).json

# Backup RabbitMQ configuration
sudo tar -czf rabbitmq-config-backup-$(date +%Y%m%d).tar.gz \
  /etc/rabbitmq/ \
  /var/lib/rabbitmq/.erlang.cookie \
  /opt/scripts/rabbitmq-cluster/
```

### 6.2 Application Logs Backup

#### 6.2.1 Log Aggregation Strategy
```yaml
Log Sources:
  - /var/log/cloud-init-output.log
  - /var/log/cso-setup.log
  - /var/log/keystone-setup-progress.log
  - /var/log/rabbitmq-setup-progress.log
  - /var/log/httpd/keystone.log
  - /var/log/rabbitmq/
  
Backup Strategy:
  CloudWatch Logs: Real-time streaming
  S3 Archive: Daily log rotation
  Local Retention: 7 days
  S3 Retention: 90 days
```

#### 6.2.2 Log Backup Automation
```bash
# Automated log backup script
#!/bin/bash
LOG_BACKUP_DIR="/opt/scripts/backups/logs"
S3_BACKUP_BUCKET="prod-ha-cso-files"
DATE=$(date +%Y%m%d)

# Create backup directory
mkdir -p "$LOG_BACKUP_DIR/$DATE"

# Collect logs from all services
sudo cp /var/log/cloud-init-output.log "$LOG_BACKUP_DIR/$DATE/"
sudo cp /var/log/*-setup*.log "$LOG_BACKUP_DIR/$DATE/" 2>/dev/null || true
sudo cp -r /var/log/httpd/ "$LOG_BACKUP_DIR/$DATE/" 2>/dev/null || true
sudo cp -r /var/log/rabbitmq/ "$LOG_BACKUP_DIR/$DATE/" 2>/dev/null || true

# Compress and upload
tar -czf "$LOG_BACKUP_DIR/logs-backup-$DATE.tar.gz" -C "$LOG_BACKUP_DIR" "$DATE"
aws s3 cp "$LOG_BACKUP_DIR/logs-backup-$DATE.tar.gz" \
  "s3://$S3_BACKUP_BUCKET/backups/logs/"

# Cleanup old local backups
find "$LOG_BACKUP_DIR" -name "logs-backup-*.tar.gz" -mtime +7 -delete
```

## 7. Disaster Recovery Procedures

### 7.1 Complete Environment Recovery

#### 7.1.1 Infrastructure Recreation
```bash
# Step 1: Prepare clean environment
git clone <repository-url> uk-msvx-cps-tf-modular-recovery
cd uk-msvx-cps-tf-modular-recovery

# Step 2: Configure Terraform backend
terraform init

# Step 3: Create or select workspace
terraform workspace new prod-ha-recovery
# OR
terraform workspace select prod-ha

# Step 4: Deploy infrastructure
./deploy.ps1 -AutoApprove

# Step 5: Verify deployment
terraform output
```

#### 7.1.2 Data Recovery Sequence
```yaml
Recovery Order:
  1. Infrastructure (Terraform) - 30 minutes
  2. Database (RDS restore) - 60 minutes  
  3. File Systems (EFS restore) - 45 minutes
  4. Secrets (automatic replication) - 5 minutes
  5. Application Configuration - 30 minutes
  6. Service Validation - 15 minutes
  
Total Recovery Time: ~3 hours
```

### 7.2 Partial Recovery Scenarios

#### 7.2.1 Single Service Recovery
```bash
# Replace failed instance
terraform taint module.compute.aws_instance.keystone[0]
terraform apply -auto-approve

# Restore service configuration
aws ssm start-session --target i-new-keystone-instance
sudo /opt/scripts/keystone-setup.sh prod-ha 1
```

#### 7.2.2 Database-Only Recovery
```bash
# Restore database from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier prod-ha-db-recovered \
  --db-snapshot-identifier prod-ha-db-manual-20241220-143022

# Update Terraform state
terraform import aws_db_instance.main prod-ha-db-recovered

# Update DNS records
terraform apply -target=module.dns
```

### 7.3 Cross-Region Disaster Recovery

#### 7.3.1 DR Environment Setup
```yaml
Primary Region: eu-west-2 (London)
DR Region: eu-west-1 (Ireland)

DR Components:
  - S3 Cross-Region Replication
  - RDS Cross-Region Snapshots
  - EFS Cross-Region Backups
  - Secrets Manager Replication
  - AMI Cross-Region Copies
```

#### 7.3.2 DR Activation Procedures
```bash
# Step 1: Switch to DR region
export AWS_DEFAULT_REGION=eu-west-1

# Step 2: Deploy infrastructure in DR region
terraform workspace new prod-ha-dr
terraform apply -var="region=eu-west-1" -var="dr_mode=true"

# Step 3: Restore database from cross-region snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier prod-ha-db-dr \
  --db-snapshot-identifier prod-ha-db-dr-20241220-143022 \
  --region eu-west-1

# Step 4: Update DNS to point to DR environment
# (Manual process or Route53 health checks)
```

## 8. Backup Monitoring and Validation

### 8.1 Backup Monitoring

#### 8.1.1 CloudWatch Alarms
```hcl
resource "aws_cloudwatch_metric_alarm" "backup_failed" {
  alarm_name          = "${var.environment}-backup-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "NumberOfBackupJobsFailed"
  namespace           = "AWS/Backup"
  period              = "86400"  # 24 hours
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Backup job failed"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

#### 8.1.2 Backup Validation Scripts
```bash
#!/bin/bash
# Daily backup validation script

echo "=== BACKUP VALIDATION REPORT $(date) ==="

# Check RDS backups
echo "1. RDS Backup Status:"
aws rds describe-db-snapshots \
  --db-instance-identifier prod-ha-db \
  --snapshot-type automated \
  --max-items 1 \
  --query 'DBSnapshots[0].[DBSnapshotIdentifier,Status,SnapshotCreateTime]' \
  --output table

# Check EFS backups
echo "2. EFS Backup Status:"
aws backup list-recovery-points \
  --backup-vault-name prod-ha-cso-backup-vault \
  --by-resource-type EFS \
  --max-items 5 \
  --query 'RecoveryPoints[].[RecoveryPointArn,Status,CreationDate]' \
  --output table

# Check S3 replication
echo "3. S3 Replication Status:"
aws s3api get-bucket-replication \
  --bucket prod-ha-cso-files \
  --query 'ReplicationConfiguration.Rules[0].Status'

# Check Secrets Manager replication
echo "4. Secrets Replication Status:"
aws secretsmanager describe-secret \
  --secret-id env-prod-ha-passwords-v2 \
  --query 'ReplicationStatus[0].Status'

echo "=== VALIDATION COMPLETE ==="
```

### 8.2 Recovery Testing

#### 8.2.1 Monthly Recovery Tests
```yaml
Test Schedule:
  Full DR Test: Quarterly
  Database Recovery: Monthly
  File System Recovery: Monthly
  Configuration Recovery: Monthly
  
Test Environment:
  Workspace: test-recovery
  Region: eu-west-1
  Duration: 4 hours
  Rollback: Automatic after test
```

#### 8.2.2 Recovery Test Procedures
```bash
# Monthly database recovery test
#!/bin/bash
TEST_DATE=$(date +%Y%m%d)
TEST_WORKSPACE="test-recovery-$TEST_DATE"

echo "Starting recovery test: $TEST_WORKSPACE"

# Create test workspace
terraform workspace new "$TEST_WORKSPACE"

# Deploy minimal infrastructure
terraform apply -var="test_mode=true" -auto-approve

# Test database recovery
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier test-db-recovery \
  --db-snapshot-identifier prod-ha-db-latest

# Validate recovery
# ... validation steps ...

# Cleanup test environment
terraform destroy -auto-approve
terraform workspace select default
terraform workspace delete "$TEST_WORKSPACE"

echo "Recovery test completed: $TEST_WORKSPACE"
```

## 9. Backup Retention and Compliance

### 9.1 Retention Policies

#### 9.1.1 Data Retention Schedule
```yaml
Critical Data (Database):
  Daily Backups: 30 days (production), 7 days (development)
  Weekly Backups: 12 weeks
  Monthly Backups: 12 months
  Yearly Backups: 7 years
  
Configuration Data:
  Version Control: Indefinite
  S3 Versions: 365 days
  EFS Snapshots: 365 days
  
Log Data:
  CloudWatch Logs: 90 days
  S3 Archive: 365 days
  Local Logs: 7 days
  
Secrets:
  Current Version: Active
  Previous Versions: 90 days
  Recovery Window: 30 days
```

#### 9.1.2 Compliance Requirements
```yaml
Regulatory Compliance:
  Data Protection: GDPR compliance for EU data
  Financial Records: 7-year retention for audit
  Security Logs: 1-year retention minimum
  Access Logs: 90-day retention minimum
  
Audit Requirements:
  Backup Verification: Monthly
  Recovery Testing: Quarterly
  Documentation Review: Annually
  Compliance Reporting: Quarterly
```

### 9.2 Cost Optimization

#### 9.2.1 Storage Cost Management
```yaml
Cost Optimization Strategy:
  S3 Intelligent Tiering: Automatic cost optimization
  EFS Lifecycle Policies: Move to IA after 30 days
  RDS Snapshot Cleanup: Automated old snapshot deletion
  Cross-Region Replication: Standard-IA storage class
  
Estimated Monthly Costs:
  RDS Backups: $50-200 (depending on size)
  EFS Backups: $20-100 (depending on data volume)
  S3 Storage: $10-50 (with lifecycle policies)
  Cross-Region: $30-150 (replication costs)
```

## 10. Emergency Procedures

### 10.1 Emergency Contacts

#### 10.1.1 Escalation Matrix
```yaml
Level 1 - Technical Team:
  - CSO DevOps Engineer: [Contact Info]
  - Database Administrator: [Contact Info]
  - System Administrator: [Contact Info]
  
Level 2 - Management:
  - CSO Technical Lead: [Contact Info]
  - Infrastructure Manager: [Contact Info]
  
Level 3 - Executive:
  - CISO: [Contact Info]
  - CTO: [Contact Info]
```

#### 10.1.2 Emergency Response Procedures
```yaml
Severity 1 (Critical):
  - Complete system outage
  - Data corruption detected
  - Security breach confirmed
  Response Time: 15 minutes
  
Severity 2 (High):
  - Service degradation
  - Backup failures
  - Performance issues
  Response Time: 1 hour
  
Severity 3 (Medium):
  - Minor service issues
  - Monitoring alerts
  - Capacity warnings
  Response Time: 4 hours
```

### 10.2 Emergency Recovery Commands

#### 10.2.1 Quick Recovery Commands
```bash
# Emergency infrastructure recreation
git clone <repo> && cd uk-msvx-cps-tf-modular
terraform init && terraform workspace select prod-ha
./deploy.ps1 -AutoApprove

# Emergency database recovery
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier prod-ha-db-emergency \
  --db-snapshot-identifier $(aws rds describe-db-snapshots \
    --db-instance-identifier prod-ha-db \
    --snapshot-type automated \
    --query 'DBSnapshots[0].DBSnapshotIdentifier' \
    --output text)

# Emergency file system recovery
aws backup start-restore-job \
  --recovery-point-arn $(aws backup list-recovery-points \
    --backup-vault-name prod-ha-cso-backup-vault \
    --by-resource-type EFS \
    --query 'RecoveryPoints[0].RecoveryPointArn' \
    --output text) \
  --metadata file-system-id=fs-emergency,Encrypted=true \
  --iam-role-arn arn:aws:iam::123456789012:role/aws-backup-service-role
```

---

**Document Version**: 1.0  
**Last Updated**: 2024-12-20  
**Author**: Infrastructure Team  
**Approved By**: CISO and Technical Architecture Board