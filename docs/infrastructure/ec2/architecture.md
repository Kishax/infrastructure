# Kishax New Infrastructure Architecture (EC2-based)

```mermaid
graph TB
    subgraph "Internet"
        Users[Users/Players]
        MCPlayers[Minecraft Players]
    end

    subgraph "AWS Cloud - ap-northeast-1"
        subgraph "Route53"
            R53MC[mc.kishax.net<br/>A Record]
            R53Web[kishax.net<br/>Alias Record]
        end

        subgraph "CloudFront"
            CF[Distribution<br/>E3J0ELKOQ6375I]
        end

        subgraph "VPC - 10.0.0.0/16"
            subgraph "Public Subnets"
                subgraph "AZ-1a Public"
                    EIP[Elastic IP<br/>57.180.207.213]
                    EC2A[i-a: MC Server<br/>t3.large On-Demand<br/>Docker + VM]
                    EC2C[i-c: Web + Discord<br/>t2.micro Spot<br/>35.77.196.146]
                end
            end

            subgraph "Private Subnets"
                subgraph "AZ-1a Private"
                    EC2B[i-b: API + Redis<br/>t3.small Spot<br/>10.0.36.61]
                    EC2D[i-d: Jump Server<br/>t2.micro On-Demand]
                end
                
                subgraph "AZ-1c Private"
                    RDSPostgres[(RDS PostgreSQL<br/>db.t4g.micro)]
                    RDSMySQL[(RDS MySQL<br/>db.t4g.micro)]
                end
            end

            IGW[Internet Gateway]
        end

        subgraph "SQS"
            SQSDiscord[Discord Queue]
            SQSToMC[To MC Queue]
            SQSToWeb[To Web Queue]
        end

        subgraph "IAM"
            IAMRoles[4 IAM Roles<br/>+ Instance Profiles]
        end

        subgraph "SSM"
            SSMParams[Parameter Store<br/>SQS Credentials]
        end
    end

    %% External connections
    MCPlayers -->|TCP 25565| R53MC
    Users -->|HTTPS| R53Web
    
    %% Route53 connections
    R53MC -->|Dynamic IP Update| EIP
    R53Web -->|Alias| CF
    
    %% CloudFront connection
    CF -->|HTTP Origin| EC2C
    
    %% EIP connection
    EIP -.->|Associated| EC2A
    
    %% Internet Gateway connections
    IGW -->|Public Access| EC2A
    IGW -->|Public Access| EC2C
    
    %% EC2 internal communications (HTTP)
    EC2A <-->|HTTP| EC2B
    EC2C <-->|HTTP| EC2B
    EC2A -.->|On 22:00-27:00| EC2C
    
    %% Database connections
    EC2A -->|MySQL| RDSMySQL
    EC2B -->|PostgreSQL| RDSPostgres
    EC2C -->|PostgreSQL| RDSPostgres
    
    %% SQS connections
    EC2A <-->|Messages| SQSToMC
    EC2B <-->|Messages| SQSDiscord
    EC2B <-->|Messages| SQSToWeb
    EC2C <-->|Messages| SQSDiscord
    
    %% Redis on EC2
    EC2B -->|Local Redis<br/>6379| EC2B
    
    %% Jump Server access
    EC2D -.->|DB Access<br/>SSM Session| RDSPostgres
    EC2D -.->|DB Access<br/>SSM Session| RDSMySQL
    
    %% IAM associations
    IAMRoles -.->|Assume Role| EC2A
    IAMRoles -.->|Assume Role| EC2B
    IAMRoles -.->|Assume Role| EC2C
    IAMRoles -.->|Assume Role| EC2D
    
    %% SSM Parameter access
    EC2B -.->|Read Credentials| SSMParams
    EC2C -.->|Read Credentials| SSMParams

    classDef internet fill:#e1f5ff,stroke:#0078d4,stroke-width:2px
    classDef cloudfront fill:#ffeaa7,stroke:#fdcb6e,stroke-width:2px
    classDef ec2 fill:#a8e6cf,stroke:#56ab2f,stroke-width:2px
    classDef rds fill:#ffcccc,stroke:#ff6b6b,stroke-width:2px
    classDef sqs fill:#dfe6e9,stroke:#636e72,stroke-width:2px
    classDef route53 fill:#ffeaa7,stroke:#fdcb6e,stroke-width:2px
    
    class Users,MCPlayers internet
    class CF cloudfront
    class EC2A,EC2B,EC2C,EC2D ec2
    class RDSPostgres,RDSMySQL rds
    class SQSDiscord,SQSToMC,SQSToWeb sqs
    class R53MC,R53Web route53
```

## Architecture Summary

### Network Architecture
- **VPC**: 10.0.0.0/16
- **Public Subnets**: 2 AZs (i-a MC Server, i-c Web Server)
- **Private Subnets**: 2 AZs (i-b API Server, i-d Jump Server, RDS instances)

### Compute Resources
1. **i-a (MC Server)**: t3.large On-Demand, 22:00-27:00 operation, Elastic IP 57.180.207.213
2. **i-b (API + Redis)**: t3.small Spot, 24/7 operation, Private IP 10.0.36.61
3. **i-c (Web + Discord)**: t2.micro Spot, 24/7 operation, Public IP 35.77.196.146
4. **i-d (Jump Server)**: t2.micro On-Demand, On-demand access only

### Database
- **RDS PostgreSQL**: db.t4g.micro (Web, API, Discord Bot)
- **RDS MySQL**: db.t4g.micro (Minecraft server data)

### Content Delivery
- **CloudFront**: Distribution E3J0ELKOQ6375I for `kishax.net`
- **Route53**: DNS records for `mc.kishax.net` and `kishax.net`

### Message Queuing
- **SQS Discord Queue**: Inter-service communication
- **SQS To MC Queue**: Messages to Minecraft server
- **SQS To Web Queue**: Messages to web application

### Security & Access
- **4 IAM Roles**: Least-privilege per EC2 instance
- **5 Security Groups**: Granular network access control
- **SSM Session Manager**: Secure access to Jump Server
- **SSM Parameter Store**: SQS credentials storage

### Cost Optimization
- Spot instances for stateless services (i-b, i-c)
- On-Demand for critical data (i-a, i-d)
- Single-AZ RDS deployment
- Redis on EC2 instead of ElastiCache
- **Target Cost**: ~$45.6/month (~¥6,900)
