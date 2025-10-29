# High Level Design (HLD) - UK MSVX CPS Infrastructure

## 1. Executive Summary

### 1.1 Purpose
This document describes the high-level architecture for the UK MSVX CPS (Chief Security Officer Shared Services Portal) infrastructure deployment on AWS. The solution provides a scalable, highly available multi-tier application platform supporting identity management, service orchestration, and administrative interfaces.

### 1.2 Business Context
The UK MSVX CPS serves as a centralized portal for managing cloud services and security operations, providing:
- **Identity and Access Management** via OpenStack Keystone
- **Service Catalog and Orchestration** capabilities
- **Message Queuing and Event Processing** through RabbitMQ
- **Administrative and User Interfaces** for portal management
- **Reporting and Analytics** for operational insights

### 1.3 Solution Overview
```
┌─────────────────────────────────────────────────────────────────┐
│                         USERS                                    │
│              (Administrators, Developers, End Users)            │
└─────────────────────┬───────────────────────────────────────────┘
                      │ HTTPS/Cognito Auth
┌─────────────────────┴───────────────────────────────────────────┐
│                 PRESENTATION LAYER                              │
│    Application Load Balancer + AWS Cognito Authentication      │
└─────────────┬───────────────────────┬─────────────────────────┘
              │                       │
┌─────────────┴─────────┐   ┌─────────┴─────────┐
│    APPLICATION LAYER  │   │    APPLICATION LAYER  │
│                       │   │                       │
│  Frontend Services    │   │  Frontend Services    │
│  - Management UI      │   │  - Management UI      │
│  - Portal UI          │   │  - Portal UI          │
│  - Admin Interface    │   │  - Admin Interface    │
└─────────┬─────────────┘   └─────────┬─────────────┘
          │                           │
┌─────────┴─────────────────────────────┴─────────┐
│              BUSINESS LOGIC LAYER                │
│                                                  │
│  Backend Services          Identity Services     │
│  - API Gateway            - Keystone (OpenStack) │
│  - Service Catalog        - Authentication       │
│  - Order Management       - Authorization        │
│  - Reporting Engine       - Token Management     │
│  - Configuration Mgmt     - Project Management   │
└─────────┬─────────────────────────────┬─────────┘
          │                             │
┌─────────┴─────────┐         ┌─────────┴─────────┐
│  INTEGRATION LAYER │         │   DATA LAYER      │
│                   │         │                   │
│  RabbitMQ Cluster │         │  RDS MySQL        │
│  - Message Queue  │         │  - Multi-AZ       │
│  - Event Bus      │         │  - Automated      │
│  - Service Mesh   │         │    Backups        │
│  - Clustering     │         │  - Encryption     │
└───────────────────┘         └───────────────────┘
```

## 2. Architecture Principles

### 2.1 Design Principles
- **High Availability**: Multi-AZ deployment with automated failover
- **Scalability**: Horizontal and vertical scaling capabilities
- **Security**: Defense in depth with multiple security layers
- **Automation**: Infrastructure as Code with Terraform
- **Observability**: Comprehensive monitoring and logging
- **Cost Optimization**: Environment-specific resource sizing

### 2.2 Technology Stack
- **Cloud Platform**: Amazon Web Services (AWS)
- **Infrastructure as Code**: Terraform with modular architecture
- **Operating System**: Amazon Linux 2023
- **Application Runtime**: Java 21 LTS, Python 3.9+
- **Web Server**: Nginx, Apache HTTP Server
- **Database**: MySQL 8.0 on Amazon RDS
- **Message Broker**: RabbitMQ with clustering
- **Identity Service**: OpenStack Keystone
- **Monitoring**: AWS CloudWatch, Performance Insights

## 3. System Architecture

### 3.1 Deployment Models

#### 3.1.1 Development Environment
```
┌─────────────────────────────────────────┐
│            Single AZ Deployment          │
│                                         │
│  ┌─────────────────────────────────────┐ │
│  │         Public Subnet               │ │
│  │  ┌─────────────────────────────────┐│ │
│  │  │      Frontend Server           ││ │
│  │  │      (Direct EIP Access)       ││ │
│  │  └─────────────────────────────────┘│ │
│  └─────────────────────────────────────┘ │
│  ┌─────────────────────────────────────┐ │
│  │         Private Subnet              │ │
│  │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐   │ │
│  │  │Back │ │Key  │ │Rabbit│ │Jump │   │ │
│  │  │end  │ │stone│ │MQ   │ │Srv  │   │ │
│  │  └─────┘ └─────┘ └─────┘ └─────┘   │ │
│  └─────────────────────────────────────┘ │
│  ┌─────────────────────────────────────┐ │
│  │           RDS MySQL                 │ │
│  │         (Single AZ)                 │ │
│  └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

#### 3.1.2 Production Environment (HA)
```
┌─────────────────────────────────────────────────────────────────┐
│                    Multi-AZ HA Deployment                       │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              Application Load Balancer                      │ │
│  │            (SSL + Cognito Authentication)                   │ │
│  └─────────────────────┬───────────────────┬───────────────────┘ │
│                        │                   │                     │
│  ┌─────────────────────┴─────────┐ ┌───────┴─────────────────────┐ │
│  │        AZ-2a                  │ │        AZ-2c                │ │
│  │  ┌─────────────────────────┐  │ │  ┌─────────────────────────┐│ │
│  │  │    Public Subnet        │  │ │  │    Public Subnet        ││ │
│  │  │    (NAT Gateway)        │  │ │  │    (NAT Gateway)        ││ │
│  │  └─────────────────────────┘  │ │  └─────────────────────────┘│ │
│  │  ┌─────────────────────────┐  │ │  ┌─────────────────────────┐│ │
│  │  │    Private Subnet       │  │ │  │    Private Subnet       ││ │
│  │  │  ┌─────┐ ┌─────┐ ┌─────┐│  │ │  │ ┌─────┐ ┌─────┐ ┌─────┐││ │
│  │  │  │Front│ │Back │ │Key  ││  │ │  │ │Front│ │Back │ │Key  │││ │
│  │  │  │end  │ │end  │ │stone││  │ │  │ │end  │ │end  │ │stone│││ │
│  │  │  └─────┘ └─────┘ └─────┘│  │ │  │ └─────┘ └─────┘ └─────┘││ │
│  │  │  ┌─────┐ ┌─────┐        │  │ │  │ ┌─────┐                ││ │
│  │  │  │Rabbit│ │Jump │        │  │ │  │ │Rabbit│                ││ │
│  │  │  │MQ   │ │Srv  │        │  │ │  │ │MQ   │                ││ │
│  │  │  └─────┘ └─────┘        │  │ │  │ └─────┘                ││ │
│  │  └─────────────────────────┘  │ │  └─────────────────────────┘│ │
│  └─────────────────────────────────┘ └─────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    RDS MySQL Multi-AZ                      │ │
│  │              (Automatic Failover)                          │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Service Architecture

#### 3.2.1 Presentation Tier
**Components:**
- **Application Load Balancer**: SSL termination, path-based routing
- **AWS Cognito**: User authentication and authorization (HA only)
- **Frontend Servers**: CSO Management UI, Portal UI, static content

**Responsibilities:**
- User interface rendering and interaction
- Session management and authentication
- Load balancing and traffic distribution
- SSL/TLS encryption and certificate management

#### 3.2.2 Application Tier
**Components:**
- **Backend Services**: 13 microservices handling business logic
- **API Gateway**: Service discovery and request routing
- **Admin Interface**: System administration and monitoring

**Service Portfolio:**
```
┌─────────────────────────────────────────────────────────────┐
│                    Backend Services                         │
├─────────────────────────────────────────────────────────────┤
│ • API Documentation (8098)    • Configuration (8103)       │
│ • Blob Store (8091)          • Customer Management (8090)  │
│ • Service Catalog (8093)     • Event Processing (8092)     │
│ • Data Export (8105)         • Order Fulfillment (8097)    │
│ • Pricing Engine (8100)      • Reporting Service (8099)    │
│ • Request Management (8096)  • Service Instances (8094)    │
│ • Ticketing System (8101)                                  │
└─────────────────────────────────────────────────────────────┘
```

#### 3.2.3 Identity and Integration Tier
**Components:**
- **OpenStack Keystone**: Identity and access management
- **RabbitMQ Cluster**: Message queuing and event processing
- **Service Mesh**: Inter-service communication

**Capabilities:**
- User authentication and token management
- Project and role-based access control
- Asynchronous message processing
- Event-driven architecture support
- Service-to-service communication

#### 3.2.4 Data Tier
**Components:**
- **Amazon RDS MySQL**: Primary data storage
- **Amazon EFS**: Shared file storage for configurations
- **Amazon S3**: Object storage for backups and artifacts

**Data Management:**
- Transactional data storage and retrieval
- Automated backups and point-in-time recovery
- Configuration and certificate management
- Log aggregation and archival

## 4. Infrastructure Design

### 4.1 Network Architecture

#### 4.1.1 VPC Design
```yaml
Network Segmentation:
  Production: 10.1.0.0/16 (65,536 IPs)
  Staging:    10.2.0.0/16 (65,536 IPs)  
  Development: 10.0.0.0/24 (256 IPs)

Subnet Strategy:
  Public Subnets:  ALB, NAT Gateways, Bastion (if needed)
  Private Subnets: Application servers, databases
  
Availability Zones:
  Primary:   eu-west-2a
  Secondary: eu-west-2c
```

#### 4.1.2 Security Architecture
```yaml
Security Layers:
  1. Network Level:
     - VPC isolation and security groups
     - Network ACLs for additional filtering
     - Private subnets for application components
     
  2. Application Level:
     - AWS Cognito authentication
     - Keystone identity management
     - Role-based access control
     
  3. Data Level:
     - Encryption at rest (EBS, RDS, EFS, S3)
     - Encryption in transit (SSL/TLS)
     - Database access controls
     
  4. Infrastructure Level:
     - IAM roles and policies
     - AWS SSM for secure access
     - CloudTrail for audit logging
```

### 4.2 Compute Architecture

#### 4.2.1 Instance Strategy
```yaml
Sizing Philosophy:
  Development:
    - Cost-optimized (t2 family)
    - Single AZ deployment
    - Basic monitoring
    
  Production:
    - Performance-optimized (c5 family)
    - Multi-AZ deployment
    - Enhanced monitoring
    
Scaling Approach:
  Current: Manual scaling via Terraform
  Future:  Auto Scaling Groups with target tracking
```

#### 4.2.2 Service Distribution
```yaml
High Availability Strategy:
  Frontend:  2 instances across AZs
  Backend:   2 instances across AZs
  Keystone:  2 instances with shared fernet keys
  RabbitMQ:  2 instances with clustering
  Database:  RDS Multi-AZ automatic failover
```

### 4.3 Storage Architecture

#### 4.3.1 Storage Strategy
```yaml
Storage Types:
  EFS (Shared):
    - Configuration files and scripts
    - SSL certificates and keys
    - Installation packages
    
  EBS (Instance):
    - Operating system and applications
    - Local caching and temporary files
    
  RDS (Database):
    - Application data and configurations
    - User accounts and permissions
    
  S3 (Object):
    - Backups and archives
    - Log files and reports
    - Terraform state files
```

#### 4.3.2 Backup Strategy
```yaml
Backup Approach:
  RDS Database:
    - Automated daily backups
    - 30-day retention (production)
    - 7-day retention (development)
    - Point-in-time recovery
    
  EFS File Systems:
    - AWS Backup integration
    - Cross-region replication (production)
    
  Configuration:
    - Git-based version control
    - Terraform state versioning
```

## 5. Integration Architecture

### 5.1 Authentication Flow
```
User Request → ALB → Cognito Auth → ALB → Frontend → Keystone → Backend Services
     ↓              ↓                ↓        ↓         ↓           ↓
   HTTPS         OAuth2           Headers   Token    Validation   API Calls
```

### 5.2 Service Communication
```yaml
Communication Patterns:
  Synchronous:
    - Frontend ↔ Backend (HTTP/HTTPS)
    - Backend ↔ Keystone (HTTPS API)
    - All Services ↔ Database (MySQL)
    
  Asynchronous:
    - Services ↔ RabbitMQ (AMQP)
    - Event-driven processing
    - Background job processing
```

### 5.3 Data Flow
```yaml
Data Movement:
  Configuration: S3 → Jump Server → EFS → All Servers
  Certificates:  Jump Server → EFS → Service Servers
  Application:   Frontend → Backend → Database
  Messages:      Services → RabbitMQ → Services
  Logs:          All Services → CloudWatch → S3
```

## 6. Operational Architecture

### 6.1 Deployment Strategy

#### 6.1.1 Infrastructure as Code
```yaml
Terraform Modules:
  - networking: VPC, subnets, load balancers
  - security:   IAM, security groups, certificates
  - compute:    EC2 instances, target groups
  - storage:    EFS, S3 buckets
  - database:   RDS MySQL
  - dns:        Route53 private zones

Environment Management:
  - Workspace isolation (dev, staging, prod-ha)
  - YAML-based configuration
  - Automated deployment scripts
```

#### 6.1.2 Application Deployment
```yaml
Deployment Process:
  1. Infrastructure provisioning (5-10 minutes)
  2. Jump server setup and file preparation (10-15 minutes)
  3. Service dependencies and clustering (15-30 minutes)
  4. Application installation and configuration (30-60 minutes)
  5. Health validation and testing (5-10 minutes)
  
Total Deployment Time: 65-125 minutes
```

### 6.2 Monitoring and Observability

#### 6.2.1 Monitoring Stack
```yaml
Infrastructure Monitoring:
  - AWS CloudWatch: Metrics and alarms
  - RDS Performance Insights: Database performance
  - ALB Access Logs: Request patterns
  - VPC Flow Logs: Network traffic
  
Application Monitoring:
  - Service health checks
  - Custom application metrics
  - Log aggregation and analysis
  - Performance tracking
```

#### 6.2.2 Alerting Strategy
```yaml
Alert Categories:
  Critical: Service outages, database failures
  Warning:  High resource utilization, slow responses
  Info:     Deployment completions, scaling events
  
Notification Channels:
  - Email notifications
  - Slack integration
  - PagerDuty escalation
```

### 6.3 Security Operations

#### 6.3.1 Access Management
```yaml
Access Methods:
  Administrative: AWS SSM Session Manager
  Application:    HTTPS via Application Load Balancer
  Database:       Private network from application servers
  
Authentication Layers:
  1. AWS IAM (infrastructure access)
  2. AWS Cognito (application access)
  3. Keystone (service authentication)
  4. CSO Application (user management)
```

#### 6.3.2 Security Monitoring
```yaml
Security Controls:
  - AWS CloudTrail: API call logging
  - AWS Config: Configuration compliance
  - Security group monitoring
  - Certificate expiration tracking
  - Failed authentication monitoring
```

## 7. Scalability and Performance

### 7.1 Performance Targets
```yaml
Response Time Objectives:
  Web Pages:      < 2 seconds
  API Calls:      < 500 milliseconds
  Database Queries: < 100 milliseconds
  File Operations: < 1 second

Throughput Objectives:
  Concurrent Users: 100-500 (production)
  API Requests:     1,000-5,000 per minute
  Database Connections: 100-500 concurrent
```

### 7.2 Scalability Strategy
```yaml
Horizontal Scaling:
  Frontend:  2-10 instances (load balancer distribution)
  Backend:   2-10 instances (internal load balancer)
  Keystone:  2-5 instances (shared state via EFS)
  RabbitMQ:  2-5 instances (cluster formation)

Vertical Scaling:
  Instance Types: t2.medium → c5.4xlarge
  Database:       db.t3.medium → db.c5.4xlarge
  Storage:        Provisioned IOPS scaling
```

## 8. Disaster Recovery and Business Continuity

### 8.1 Recovery Objectives
```yaml
Recovery Targets:
  RTO (Recovery Time Objective):  4 hours
  RPO (Recovery Point Objective): 1 hour
  
Availability Targets:
  Development:  99.0% (8.76 hours/month downtime)
  Production:   99.9% (43.2 minutes/month downtime)
```

### 8.2 Backup and Recovery
```yaml
Backup Strategy:
  Database:     Automated daily backups with point-in-time recovery
  Configuration: Git version control and EFS snapshots
  Infrastructure: Terraform state versioning
  
Recovery Procedures:
  Database:     RDS automated failover and restore
  Application:  Infrastructure recreation via Terraform
  Configuration: Git rollback and redeployment
```

## 9. Cost Optimization

### 9.1 Cost Management Strategy
```yaml
Cost Optimization:
  Right-sizing: Environment-specific instance types
  Storage:      EFS lifecycle policies (IA after 30 days)
  Database:     Auto-scaling storage
  Networking:   VPC endpoints for AWS services
  
Reserved Capacity:
  Production:   Reserved Instances for predictable workloads
  Development: On-demand instances for flexibility
```

### 9.2 Resource Tagging
```yaml
Tagging Strategy:
  Environment: dev, staging, prod-ha
  Project:     CSO HA Primary
  Owner:       CSO Team
  CostCenter:  Nimbus
  Compliance:  required
```

## 10. Future Roadmap

### 10.1 Planned Enhancements
```yaml
Short Term (3-6 months):
  - Auto Scaling Groups implementation
  - Enhanced monitoring and alerting
  - Automated testing integration
  
Medium Term (6-12 months):
  - Container migration (EKS)
  - Service mesh implementation
  - Multi-region deployment
  
Long Term (12+ months):
  - Serverless components
  - AI/ML integration
  - Edge computing capabilities
```

### 10.2 Technology Evolution
```yaml
Migration Path:
  Current:  VM-based deployment
  Target:   Container-based microservices
  
Architecture Evolution:
  Current:  Monolithic services
  Target:   Cloud-native microservices
  
Operational Evolution:
  Current:  Manual scaling and management
  Target:   Automated operations and self-healing
```

---

**Document Version**: 1.0  
**Last Updated**: 2024-12-20  
**Author**: Architecture Team  
**Approved By**: Technical Architecture Board