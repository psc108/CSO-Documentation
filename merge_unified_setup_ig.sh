#!/bin/bash
# Transfer unified-setup script documentation to SecureCloud IG template

set -e

SCRIPT_DIR="/home/scottp/IdeaProjects/CSO-Documentation"
TEMPLATE="$SCRIPT_DIR/docx/Templates/SecureCloud_service_IG_xxx_Template_v0.1.docx"
SOURCE_SCRIPT="$SCRIPT_DIR/unified-setup-for-conversion"
OUTPUT="$SCRIPT_DIR/docx/Unified_Setup_IG_Final.docx"
TEMP_DIR="/tmp/ig_merge_$$"

echo "========================================="
echo "Unified Setup IG Template Merge Process"
echo "========================================="

mkdir -p "$TEMP_DIR"

cat > "$TEMP_DIR/ig_formatted.md" << 'MDEOF'
# 1. Introduction

## 1.1 Purpose

This Installation Guide provides comprehensive instructions for deploying the UK MSVX CPS (Chief Security Officer Shared Services Portal) infrastructure using the unified server setup script. The script automates the deployment of all server types including Jump Server, Keystone, RabbitMQ, Backend, and Frontend servers.

## 1.2 Scope

This guide covers:

- Unified server deployment script overview and architecture
- Prerequisites and requirements for deployment
- Installation procedures for each server type
- Configuration parameters and auto-detection
- Troubleshooting and validation procedures
- Post-installation verification steps

## 1.3 Audience

This guide is intended for:

- Infrastructure Engineers responsible for AWS deployments
- DevOps Engineers managing CSO infrastructure
- System Administrators performing server installations
- Technical Support Staff troubleshooting deployments

# 2. Overview

## 2.1 Unified Setup Script

The unified-server-setup.sh script (Version 3.0) is a specification-compliant deployment automation tool that handles the complete installation and configuration of all CSO infrastructure server types.

### Key Features

- **Auto-Detection**: Automatically detects environment, server type, and configuration from AWS metadata
- **Unified Deployment**: Single script handles all server types (jump, keystone, rabbitmq, backend, frontend)
- **Structured Logging**: Comprehensive logging with timestamps, severity levels, and progress tracking
- **Error Handling**: Robust error handling with validation and rollback capabilities
- **AWS Integration**: Native integration with AWS services (EC2, RDS, EFS, Secrets Manager, S3)

### Supported Server Types

1. **Jump Server**: Administrative access, file distribution, installation package extraction
2. **Keystone Server**: OpenStack identity service with Apache WSGI
3. **RabbitMQ Server**: Message broker with clustering support
4. **Backend Server**: 13 microservices for business logic and APIs
5. **Frontend Server**: Web UI (Management and Portal interfaces)

## 2.2 Deployment Architecture

The script follows a sequential deployment pattern:

```
1. Jump Server → Extracts installation files to EFS
2. Keystone Servers → Identity service setup
3. RabbitMQ Servers → Message broker clustering
4. Backend Servers → API services and databases
5. Frontend Servers → Web interfaces
```

# 3. Prerequisites

## 3.1 AWS Infrastructure Requirements

### Required AWS Resources

- **VPC**: Configured with public and private subnets across 2 availability zones
- **EC2 Instances**: Amazon Linux 2023 instances with appropriate instance types
- **RDS MySQL**: Database instance (Multi-AZ for HA)
- **EFS**: Elastic File System for shared storage
- **S3 Bucket**: Installation files and packages
- **IAM Roles**: EC2 instance role with required permissions
- **Security Groups**: Configured for inter-server communication

### IAM Permissions Required

The EC2 instance role must have permissions for:

- EC2: describe-instances, describe-tags
- RDS: describe-db-instances
- EFS: describe-file-systems
- S3: GetObject, ListBucket
- Secrets Manager: GetSecretValue
- SSM: Session Manager access

## 3.2 Network Requirements

### Connectivity

- Internet access for package downloads (via NAT Gateway)
- EFS mount targets in private subnets
- RDS endpoint accessible from private subnets
- Inter-server communication on required ports

### DNS Configuration

- Private Route53 hosted zone configured
- DNS records for all servers
- RDS endpoint DNS resolution

## 3.3 Software Requirements

### Pre-installed on Amazon Linux 2023

- Python 3.9+
- AWS CLI
- curl, wget
- systemd

### Installed by Script

- Java 21 (Amazon Corretto)
- Nginx
- Apache HTTP Server
- RabbitMQ and Erlang
- Python packages (keystone, PyMySQL, etc.)
- Node.js and npm

## 3.4 Required Files and Packages

### S3 Bucket Contents

- **installation-package*.jar**: CSO application installation package
- **installer_p3.py**: Fixed installer script
- **rabbitmq-server-3.13.3-1.el8.noarch.rpm**: RabbitMQ server package

### EFS Shared Storage

- **/opt/scripts**: Deployment scripts and configurations
- **/opt/ssl-certs**: SSL certificates and keys
- **/opt/install**: Extracted installation files

# 4. Installation Procedures

## 4.1 Script Execution Methods

### Method 1: Auto-Detection (Recommended)

The script automatically detects all parameters from AWS metadata:

```bash
./unified-server-setup.sh
```

**Auto-detected Parameters:**
- Environment (from EC2 tags)
- Server Type (from instance name)
- Server Index (from instance name)
- EFS DNS Name (from EFS tags)
- S3 Bucket (default or from tags)

### Method 2: Manual Parameters

Specify parameters explicitly:

```bash
./unified-server-setup.sh ENVIRONMENT SERVER_TYPE SERVER_INDEX [EFS_DNS] [S3_BUCKET]
```

**Parameters:**
- **ENVIRONMENT**: dev, staging, prod-ha
- **SERVER_TYPE**: jump, keystone, rabbitmq, backend, frontend
- **SERVER_INDEX**: 1, 2, 3, etc.
- **EFS_DNS**: EFS DNS name (optional, auto-detected)
- **S3_BUCKET**: S3 bucket name (optional, uses default)

**Example:**
```bash
./unified-server-setup.sh prod-ha backend 1
```

## 4.2 Jump Server Installation

The Jump Server is deployed first and prepares the environment for all other servers.

### Installation Steps

1. **Execute Script**
   ```bash
   ./unified-server-setup.sh prod-ha jump 1
   ```

2. **Script Actions**
   - Updates system packages
   - Installs nginx, python3, unzip
   - Mounts EFS at /opt/scripts
   - Downloads installation package from S3
   - Extracts CSO installation files
   - Deploys fixed installer_p3.py
   - Creates completion marker

3. **Verification**
   ```bash
   # Check nginx status
   systemctl status nginx
   
   # Verify installation files
   ls -la /opt/install/installer_p3.py
   
   # Check completion marker
   cat /opt/scripts/.setup-complete
   ```

### Jump Server Configuration

**Nginx Configuration** (/etc/nginx/conf.d/jump.conf):
- Port 80: Health check and status page
- Document root: /var/www/html
- Health endpoint: /health

**Installation Files** (/opt/install/):
- installer_p3.py: Main installer script
- CSO application packages
- Configuration files

### Expected Duration

- System updates: 2-5 minutes
- Package installation: 3-5 minutes
- File extraction: 5-10 minutes
- **Total: 10-20 minutes**

## 4.3 Keystone Server Installation

Keystone provides identity and authentication services for the CSO platform.

### Installation Steps

1. **Execute Script**
   ```bash
   ./unified-server-setup.sh prod-ha keystone 1
   ```

2. **Script Actions**
   - Installs Python development tools, Apache, mod_ssl
   - Creates Python virtual environment
   - Installs OpenStack Keystone packages
   - Configures database connection
   - Initializes Keystone database (primary server only)
   - Sets up Fernet tokens
   - Configures Apache WSGI
   - Starts Apache service

3. **Verification**
   ```bash
   # Check Apache status
   systemctl status httpd
   
   # Test Keystone API
   curl -k https://localhost:5000/api/idm/v3/
   
   # Check database connection
   mysql -h <RDS_ENDPOINT> -u keystone -p -e "SHOW DATABASES;"
   ```

### Keystone Configuration

**Database Configuration** (/etc/keystone/keystone.conf):
```ini
[database]
connection = mysql+pymysql://keystone:<PASSWORD>@<RDS_ENDPOINT>/keystone

[token]
provider = fernet
```

**Apache WSGI** (/etc/httpd/conf.d/wsgi-keystone.conf):
- Port 5000: Keystone API endpoint
- WSGI processes: 5 workers
- Application path: /api/idm

### Primary vs Secondary Servers

**Primary Server (Index 1):**
- Creates keystone database
- Runs db_sync
- Generates Fernet keys
- Runs bootstrap

**Secondary Servers (Index 2+):**
- Connects to existing database
- Uses shared Fernet keys from EFS
- No bootstrap required

### Expected Duration

- Package installation: 5-10 minutes
- Database initialization: 2-5 minutes (primary only)
- Apache configuration: 2-3 minutes
- **Total: 10-20 minutes**

## 4.4 RabbitMQ Server Installation

RabbitMQ provides message queuing and event processing for the CSO platform.

### Installation Steps

1. **Execute Script**
   ```bash
   ./unified-server-setup.sh prod-ha rabbitmq 1
   ```

2. **Script Actions**
   - Installs Erlang runtime
   - Downloads and installs RabbitMQ from S3
   - Starts RabbitMQ service
   - Enables management plugin
   - Creates admin user and vhost (primary server only)
   - Configures clustering (if multiple servers)

3. **Verification**
   ```bash
   # Check RabbitMQ status
   systemctl status rabbitmq-server
   
   # Check cluster status
   rabbitmqctl cluster_status
   
   # Test management interface
   curl -u admin:<PASSWORD> http://localhost:15672/api/overview
   ```

### RabbitMQ Configuration

**Service Ports:**
- 5672: AMQP protocol
- 5671: AMQP over SSL
- 15672: Management HTTP
- 15671: Management HTTPS

**Virtual Hosts:**
- /ssp: CSO application vhost

**Users:**
- admin: Administrator with full permissions

### Clustering Configuration

For HA deployments with multiple RabbitMQ servers:

1. Primary server creates Erlang cookie
2. Secondary servers join cluster
3. HA policy applied: mirror all queues
4. Automatic failover enabled

### Expected Duration

- Erlang installation: 2-3 minutes
- RabbitMQ installation: 3-5 minutes
- Service configuration: 2-3 minutes
- **Total: 7-12 minutes**

## 4.5 Backend Server Installation

Backend servers host the 13 microservices that provide business logic and APIs.

### Installation Steps

1. **Execute Script**
   ```bash
   ./unified-server-setup.sh prod-ha backend 1
   ```

2. **Script Actions**
   - Installs Java 21, Node.js, Nginx
   - Configures Nginx for HTTPS
   - Waits for Keystone availability
   - Retrieves RDS credentials
   - Creates application databases
   - Runs CSO installer for backend services
   - Starts backend services

3. **Verification**
   ```bash
   # Check Nginx status
   systemctl status nginx
   
   # Test backend API
   curl -k https://localhost/api/health
   
   # Check databases
   mysql -h <RDS_ENDPOINT> -u admin -p -e "SHOW DATABASES LIKE 'ecs_%';"
   ```

### Backend Services

**Microservices (Ports 8090-8105):**
- 8090: Customer Management
- 8091: Blob Store
- 8092: Event Processing
- 8093: Service Catalog
- 8094: Service Instances
- 8096: Request Management
- 8097: Order Fulfillment
- 8098: API Documentation
- 8099: Reporting Service
- 8100: Pricing Engine
- 8101: Ticketing System
- 8103: Configuration Service
- 8105: Data Export

### Database Configuration

**Created Databases:**
- ecs_catalog
- ecs_blobstore
- ecs_customers
- ecs_request
- ecs_fulfill
- ecs_svcinst
- ecs_pricing
- ecs_reporting
- ecs_config
- ecs_export
- ecs_ticketing
- ecs_event

Each database has a dedicated user with full permissions.

### Expected Duration

- Package installation: 5-10 minutes
- Database creation: 2-3 minutes
- CSO installation: 30-60 minutes
- **Total: 40-75 minutes**

## 4.6 Frontend Server Installation

Frontend servers host the web interfaces for the CSO platform.

### Installation Steps

1. **Execute Script**
   ```bash
   ./unified-server-setup.sh prod-ha frontend 1
   ```

2. **Script Actions**
   - Installs Java 21, Node.js, Nginx
   - Configures Nginx for HTTPS and proxying
   - Waits for Keystone availability
   - Runs CSO installer for frontend services
   - Starts frontend services

3. **Verification**
   ```bash
   # Check Nginx status
   systemctl status nginx
   
   # Test Management UI
   curl -k https://localhost/admin
   
   # Test Portal UI
   curl -k https://localhost/
   ```

### Frontend Services

**Web Interfaces:**
- Port 8102: Management UI (Admin interface)
- Port 8202: Portal UI (User interface)
- Port 443: HTTPS (Nginx proxy)

### Nginx Configuration

**Proxy Configuration** (/etc/nginx/conf.d/cso.conf):
- /admin → localhost:8102 (Management UI)
- / → localhost:8202 (Portal UI)
- SSL termination with self-signed certificates

### Expected Duration

- Package installation: 5-10 minutes
- CSO installation: 30-60 minutes
- **Total: 35-70 minutes**

# 5. Configuration Details

## 5.1 Auto-Detection Mechanism

The script uses AWS metadata and APIs to automatically detect configuration:

### EC2 Metadata Service

```bash
# Instance ID
curl http://169.254.169.254/latest/meta-data/instance-id

# Instance tags (via AWS CLI)
aws ec2 describe-instances --instance-ids <INSTANCE_ID>
```

### Parameter Detection Logic

1. **Environment**: Extracted from EC2 tag "Environment"
2. **Server Type**: Parsed from instance name (e.g., "backend-server-1" → "backend")
3. **Server Index**: Extracted from instance name suffix (e.g., "-1" → 1)
4. **EFS DNS**: Queried from EFS API using environment tag
5. **S3 Bucket**: Uses default or from configuration

## 5.2 Password Management

Passwords are retrieved from AWS Secrets Manager:

### Secret Structure

Secret Name: `{environment}-service-passwords`

```json
{
  "rabbitmq_password": "RabbitPass123",
  "service_password": "ServicePass123",
  "keystone_password": "KeystonePass123",
  "admin_password": "AdminPass123"
}
```

### Fallback Behavior

If Secrets Manager is unavailable, the script uses default passwords (not recommended for production).

## 5.3 Logging Configuration

### Log Files

- **/var/log/cso-install.log**: Main installation log (all output)
- **/var/log/{server_type}-setup-progress.log**: Progress tracking
- **/var/log/keystone-setup-progress.log**: Keystone-specific progress
- **/var/log/rabbitmq-setup-progress.log**: RabbitMQ-specific progress

### Log Format

```
[YYYY-MM-DD HH:MM:SS] [LEVEL] [SERVER_TYPE] [FUNCTION] Message
```

**Log Levels:**
- INFO: Informational messages
- SUCCESS: Successful operations
- WARNING: Non-critical issues
- ERROR: Critical failures
- PROGRESS: Deployment progress milestones
- DEBUG: Detailed debugging (when DEBUG=true)

## 5.4 Completion Markers

The script creates marker files to track deployment status:

- **/opt/scripts/.setup-complete**: Jump server completion
- **/opt/scripts/.keystone-done**: Keystone ready for dependencies
- **/opt/scripts/.{server_type}-setup-complete**: Individual server completion

# 6. Troubleshooting

## 6.1 Common Issues

### Issue: Script Cannot Detect Parameters

**Symptoms:**
- Error: "ENVIRONMENT parameter required"
- Error: "SERVER_TYPE parameter required"

**Resolution:**
1. Verify EC2 instance has "Environment" tag
2. Verify instance name follows naming convention
3. Run with manual parameters:
   ```bash
   ./unified-server-setup.sh prod-ha backend 1
   ```

### Issue: EFS Mount Fails

**Symptoms:**
- Error: "mount.nfs4: Connection timed out"
- /opt/scripts not accessible

**Resolution:**
1. Verify EFS security group allows NFS (port 2049)
2. Verify EFS mount targets exist in instance subnets
3. Check EFS DNS name:
   ```bash
   aws efs describe-file-systems
   ```

### Issue: RDS Connection Fails

**Symptoms:**
- Error: "Can't connect to MySQL server"
- Database initialization fails

**Resolution:**
1. Verify RDS security group allows MySQL (port 3306)
2. Verify RDS endpoint is accessible:
   ```bash
   telnet <RDS_ENDPOINT> 3306
   ```
3. Check RDS status:
   ```bash
   aws rds describe-db-instances
   ```

### Issue: Keystone Timeout

**Symptoms:**
- Backend/Frontend waiting indefinitely for Keystone
- Warning: "Keystone timeout"

**Resolution:**
1. Check Keystone server status:
   ```bash
   systemctl status httpd
   ```
2. Verify Keystone API:
   ```bash
   curl -k https://<KEYSTONE_IP>:5000/api/idm/v3/
   ```
3. Check completion marker:
   ```bash
   ls -la /opt/scripts/.keystone-done
   ```

### Issue: Installation Package Not Found

**Symptoms:**
- Error: "CSO installation package not found"
- Jump server extraction fails

**Resolution:**
1. Verify S3 bucket access:
   ```bash
   aws s3 ls s3://<BUCKET_NAME>/
   ```
2. Check for installation package:
   ```bash
   find /opt/scripts -name "installation-package*.jar"
   ```
3. Verify IAM role has S3 read permissions

## 6.2 Validation Commands

### System Validation

```bash
# Check system updates
dnf check-update

# Verify required packages
rpm -qa | grep -E "java|python3|nginx|httpd"

# Check disk space
df -h

# Check memory
free -h
```

### Service Validation

```bash
# Check all services
systemctl list-units --type=service --state=running

# Specific service checks
systemctl status nginx
systemctl status httpd
systemctl status rabbitmq-server
```

### Network Validation

```bash
# Check listening ports
ss -tlnp

# Test connectivity
curl -k https://localhost:5000/api/idm/v3/  # Keystone
curl http://localhost:15672/api/overview    # RabbitMQ
curl -k https://localhost/api/health        # Backend
```

### Database Validation

```bash
# Connect to RDS
mysql -h <RDS_ENDPOINT> -u admin -p

# List databases
SHOW DATABASES;

# Check keystone database
USE keystone;
SHOW TABLES;

# Check backend databases
SHOW DATABASES LIKE 'ecs_%';
```

## 6.3 Log Analysis

### View Real-time Logs

```bash
# Main installation log
tail -f /var/log/cso-install.log

# Progress log
tail -f /var/log/{server_type}-setup-progress.log

# Filter by log level
grep ERROR /var/log/cso-install.log
grep WARNING /var/log/cso-install.log
```

### Search for Specific Issues

```bash
# Find errors
grep -i error /var/log/cso-install.log

# Find timeouts
grep -i timeout /var/log/cso-install.log

# Find AWS API calls
grep "AWS API call" /var/log/cso-install.log
```

# 7. Post-Installation

## 7.1 Verification Checklist

### Jump Server

- [ ] Nginx running on port 80
- [ ] Installation files extracted to /opt/install
- [ ] installer_p3.py exists and is executable
- [ ] Completion marker created: /opt/scripts/.setup-complete

### Keystone Server

- [ ] Apache running on port 5000
- [ ] Keystone API responding: https://localhost:5000/api/idm/v3/
- [ ] Database initialized (primary server)
- [ ] Fernet keys generated
- [ ] Completion marker created: /opt/scripts/.keystone-done

### RabbitMQ Server

- [ ] RabbitMQ service running
- [ ] Management plugin enabled
- [ ] Admin user created
- [ ] Vhost /ssp created
- [ ] Management interface accessible: http://localhost:15672

### Backend Server

- [ ] Nginx running on port 443
- [ ] All backend databases created (ecs_*)
- [ ] Backend services responding
- [ ] API endpoints accessible

### Frontend Server

- [ ] Nginx running on ports 443, 8102, 8202
- [ ] Management UI accessible
- [ ] Portal UI accessible
- [ ] SSL certificates configured

## 7.2 Security Hardening

### Recommended Post-Installation Steps

1. **Replace Self-Signed Certificates**
   - Generate proper SSL certificates
   - Update Nginx and Apache configurations
   - Restart services

2. **Change Default Passwords**
   - Update Secrets Manager with strong passwords
   - Rotate RabbitMQ admin password
   - Update database passwords

3. **Configure Firewall Rules**
   - Restrict access to management interfaces
   - Limit SSH access (use SSM Session Manager)
   - Configure security group rules

4. **Enable Audit Logging**
   - Configure CloudWatch Logs
   - Enable RDS audit logging
   - Set up log retention policies

## 7.3 Backup Procedures

### Configuration Backup

```bash
# Backup EFS contents
aws backup start-backup-job \
  --backup-vault-name <VAULT_NAME> \
  --resource-arn <EFS_ARN>

# Backup RDS
aws rds create-db-snapshot \
  --db-instance-identifier <DB_INSTANCE> \
  --db-snapshot-identifier <SNAPSHOT_NAME>
```

### Script Backup

```bash
# Backup deployment scripts
tar -czf scripts-backup-$(date +%Y%m%d).tar.gz /opt/scripts/

# Upload to S3
aws s3 cp scripts-backup-*.tar.gz s3://<BACKUP_BUCKET>/
```

# 8. Appendix

## 8.1 Script Parameters Reference

| Parameter | Required | Description | Example |
|-----------|----------|-------------|---------|
| ENVIRONMENT | Yes | Deployment environment | dev, staging, prod-ha |
| SERVER_TYPE | Yes | Type of server to deploy | jump, keystone, rabbitmq, backend, frontend |
| SERVER_INDEX | No | Server instance number (default: 1) | 1, 2, 3 |
| EFS_DNS_NAME | No | EFS DNS name (auto-detected) | fs-12345678.efs.eu-west-2.amazonaws.com |
| S3_BUCKET | No | S3 bucket for files (default provided) | cso-ha-install-files-365612464816 |

## 8.2 Port Reference

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| Nginx (Jump) | 80 | HTTP | Health check, status |
| Keystone | 5000 | HTTPS | Identity API |
| RabbitMQ | 5672 | AMQP | Message queue |
| RabbitMQ SSL | 5671 | AMQPS | Secure message queue |
| RabbitMQ Mgmt | 15672 | HTTP | Management interface |
| Backend Services | 8090-8105 | HTTP | Microservices APIs |
| Frontend Admin | 8102 | HTTP | Management UI |
| Frontend Portal | 8202 | HTTP | Portal UI |
| HTTPS | 443 | HTTPS | Secure web access |
| MySQL | 3306 | TCP | Database |
| NFS | 2049 | TCP | EFS mount |

## 8.3 File Locations Reference

| Path | Purpose |
|------|---------|
| /opt/scripts | EFS mount for shared scripts |
| /opt/ssl-certs | EFS mount for SSL certificates |
| /opt/install | Extracted installation files |
| /opt/keystone-venv | Keystone Python virtual environment |
| /etc/keystone | Keystone configuration |
| /etc/nginx/conf.d | Nginx configuration files |
| /etc/httpd/conf.d | Apache configuration files |
| /var/log/cso-install.log | Main installation log |
| /var/log/*-setup-progress.log | Progress tracking logs |

## 8.4 AWS Resources Reference

| Resource | Purpose |
|----------|---------|
| EC2 Instances | Application servers |
| RDS MySQL | Database service |
| EFS | Shared file storage |
| S3 Bucket | Installation packages |
| Secrets Manager | Password storage |
| IAM Roles | Instance permissions |
| Security Groups | Network access control |
| Route53 | Private DNS |
| CloudWatch | Logging and monitoring |

## 8.5 Definitions and Conventions

| Term/Acronym | Definition |
|--------------|------------|
| ALB | Application Load Balancer |
| AMQP | Advanced Message Queuing Protocol |
| API | Application Programming Interface |
| AWS | Amazon Web Services |
| CSO | Chief Security Officer |
| DNS | Domain Name System |
| EBS | Elastic Block Store |
| EC2 | Elastic Compute Cloud |
| EFS | Elastic File System |
| HA | High Availability |
| HTTP | Hypertext Transfer Protocol |
| HTTPS | HTTP Secure |
| IAM | Identity and Access Management |
| IG | Installation Guide |
| MSVX | Multi-Service Virtual Exchange |
| NFS | Network File System |
| RDS | Relational Database Service |
| S3 | Simple Storage Service |
| SSL | Secure Sockets Layer |
| SSM | Systems Manager |
| TLS | Transport Layer Security |
| UI | User Interface |
| VPC | Virtual Private Cloud |
| WSGI | Web Server Gateway Interface |

MDEOF

echo "Step 2: Converting to DOCX with template..."
pandoc "$TEMP_DIR/ig_formatted.md" \
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
echo "2. Update the cover page (author, date, version)"
echo "3. Fill in Document Information table"
echo "4. Update Version History table"
echo "5. Add Document References"
echo "6. Update Table of Contents (right-click → Update Field)"
echo "7. Review all procedures and commands"
echo ""

rm -rf "$TEMP_DIR"
