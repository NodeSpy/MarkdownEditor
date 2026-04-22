# AWS Cost Savings Proposal — TeacherMade

**Prepared:** February 2026

---

## 1. Current spend (from Cost Explorer)

Approximate **January 2026** run rate (monthly):

| Service | Jan 2026 | Notes |
|--------|----------|--------|
| **Amazon RDS** | ~$5,003 | Aurora (prod db.r6g.2xlarge ×2, stage db.r6g.large ×2, plus Rundeck/FTFT db.t3.medium) |
| **Amazon ECS (Fargate)** | ~$2,048 | Django, Celery, tm-analytics, table-compactor, etc. |
| **Amazon Polly** | ~$1,021 | TTS – no RI/SP; usage-based |
| **EC2 – Other** | ~$895 | EBS, NAT data processing, etc. |
| **Amazon EFS** | ~$451 | Shared storage for analytics / workloads |
| **AWS Config** | ~$424 | Rule evaluations, config recorder |
| **AWS Support (Developer)** | ~$344 | Fixed by support tier |
| **Amazon CloudFront** | ~$524 | CDN |
| **Amazon ElastiCache** | ~$162 | Valkey (cache.t3.medium/small) |
| **Amazon EC2 (Compute)** | ~$182 | GHA (m5.large), Rundeck (t3.medium), OpenVPN (t3.small), bastion (t3.nano), etc. |
| **AWS WAF** | ~$113 | Web application firewall |
| **Amazon ELB** | ~$92 | ALBs |
| **Amazon VPC** | ~$323 (Feb) | Largely 3× NAT Gateway in prod |
| **Other** | ~$300+ | KMS, S3, SQS, Route 53, DataSync, MediaConvert, etc. |

**Rough total:** ~$15k–$16k/month (excluding tax).
**No existing Reserved Instances or Savings Plans** are in use (utilization is 0%).

---

## 2. Recommended purchases (all 1-year, No Upfront)

### 2.1 Compute Savings Plan (1-year, No Upfront)

- **Covers:** Fargate, Lambda, EC2 (all regions, all instance types).
- **Recommendation:** **1-year, No Upfront** at $1.057/hr (~$761/yr commitment). Saves **~$198/month** on compute. Best single lever for your Fargate + EC2 + Lambda mix.

### 2.2 RDS Reserved Instances (1-year, No Upfront)

- **Covers:** Aurora PostgreSQL and other RDS in the same family/region.

| Recommendation | Est. monthly savings |
|----------------|----------------------|
| **10 × db.r6g.large (size-flexible)** | **~$657/month** (~31%) |
| **2 × db.t3.small (size-flexible)** | **~$12/month** (~20%) |
| **Total RDS** | **~$669/month** |

Buy **size-flexible** in **db.r6g** and **db.t3** so they apply to your actual sizes (db.r6g.2xlarge, db.r6g.large, db.t3.medium).

### 2.3 ElastiCache Reserved Cache Nodes (1-year, No Upfront)

- **Covers:** Valkey/Redis (cache.t3.*) in the same region.
- **Recommendation:** **16 × cache.t3.micro (size-flexible)**. Saves **~$47/month** (~29%). Purchase as size-flexible so it applies to your cache.t3.medium and cache.t3.small nodes.

**Skip EC2 RIs for now** — the Compute Savings Plan already covers EC2; adding EC2 RIs risks over-commitment. Revisit later if needed.

### 2.4 CloudFront Security Savings Bundle (1-year)

- **Current spend:** CloudFront ~$524 + WAF ~$113 → **~$637/month** combined.
- **What it is:** 1-year monthly usage commitment that gives **up to 30% savings** on CloudFront. WAF for CloudFront is free up to 10% of your committed amount.
- **Recommendation:** Commit ~**$367/month** (CloudFront × 0.70). Saves **~$157–$194/month** (CloudFront discount + partial WAF credit). Use the CloudFront console recommendation based on your historical usage to set the exact commitment.

---

## 3. Bundles

Use **Compute SP + RDS RIs + ElastiCache RIs + CloudFront Security Savings Bundle** together; all No Upfront. See **§ 5** for more opportunities (EC2 RIs, Fargate Spot, GHA Spot, S3, CloudWatch, EBS, Graviton, NAT, Config, Support, Polly, EFS, etc.).

---

## 4. Estimated total savings (recommended commitments)

| Action | Est. monthly savings |
|--------|----------------------|
| Compute Savings Plan (1-year) | ~$198 |
| RDS RIs (1-year) | ~$669 |
| ElastiCache RIs (1-year) | ~$47 |
| CloudFront Security Savings Bundle (1-year) | ~$157–$194 |
| **Total** | **~$1,071–$1,108/month** |

**Upfront cost:** $0 (all No Upfront; CFSSB is a monthly commitment).

Roughly **~7%** of a $15k–$16k monthly bill, with no capital outlay.

---

## 5. Other savings opportunities

### 5.1 Big wins: storage and data transfer (researched against your account)

Data below from **Cost Explorer and API** (Jan 2026). Prod Aurora PostgreSQL has **35 days** retention; staging 5; Rundeck 21.

| Opportunity | Your actual numbers | Action and estimated savings |
|-------------|---------------------|------------------------------|
| **RDS / Aurora backup retention** | **Jan 2026 RDS backup cost:** Aurora:BackupUsage **$1,704** + RDS:ChargedBackupUsage **$281** → **~$1,985/mo** for backup storage. Prod is the 35-day cluster. | Reduce prod to 7–14 days (and review AWS Backup vault retention). **Est. savings: ~$500–$1,200/mo** (depends how much of the $1,704 is from prod's 35-day window). Align with recovery needs first. |
| **EBS volumes and snapshots** | **Unattached volumes:** **0** (none). **Snapshots:** 36 snapshots, **4,086 GB** total. Jan EBS:SnapshotUsage **$69.19** (1,383.8 GB-month). By age: 2023 = 17 snapshots / 136 GB; 2024 = 4 / 274 GB; 2025 = 15 / 3,676 GB. | No savings from unattached volumes. Deleting old snapshots (e.g. all 2023: 136 GB) saves **~$7/mo**. Prefer gp3 over gp2. **Bottom line: small win (~$7/mo)** unless more unused snapshots found. |
| **VPC endpoints (SQS, KMS, STS)** | **Jan 2026 NAT:** NatGateway-Bytes **$489.70** for **10,882 GB (10.9 TB)** data processing; NatGateway-Hours $301.32 (3 NATs). NAT = $0.045/GB. You have S3, ECR, SSM, Secrets Manager, Logs; you do **not** have SQS, KMS, STS. | Add **Interface** VPC endpoints for SQS, KMS, STS (and SNS if you publish from private subnet). Endpoint cost: ~$0.01/hr per AZ → 3 endpoints × 3 AZs ≈ **~$66/mo**. Endpoint data $0.01/GB (vs NAT $0.045/GB). Break-even: **~1,886 GB** moved. If **2–4 TB** of 10.9 TB is SQS/KMS/STS traffic, **net savings ~$40–$110/mo** after endpoint cost. |

| Opportunity | What it is | Est. impact / notes |
|-------------|------------|---------------------|
| **Fargate Spot** | Run interruptible ECS tasks on Spot capacity (e.g. Celery heavy_processing, table-compactor, migrate, batch-style tm-analytics). | Up to ~70% discount on those tasks. Requires capacity provider config and tolerance for interruption. |
| **GHA Spot instances** | Use Spot instead of On-Demand for GitHub Actions runners (Spot is currently commented out in your GHA launch template). | Often 50–70% cheaper than On-Demand for the same EC2 usage. |
| **S3 storage classes** | Use S3 Intelligent-Tiering or lifecycle rules (e.g. move to STANDARD_IA / Glacier after 30–90 days) for buckets that don't need instant access. | S3 was ~\$293/mo (Feb); tiering/lifecycle can cut storage cost for older data. You already use IA/Glacier in s3_replication. |
| **RDS / Backup snapshot retention** | Prod Aurora: **35 days** + AWS Backup vault. Reduce to 7–14 days and review vault retention. | **§ 5.1.** Jan backup cost **~$1,985/mo** (Aurora $1,704 + RDS ChargedBackup $281). Est. savings **~$500–$1,200/mo** if retention reduced. |
| **VPC endpoints (SQS, KMS, STS)** | Add Interface endpoints for **SQS**, **KMS**, **STS** (and **SNS** if needed). You already have S3, ECR, SSM, Secrets Manager, Logs. | **§ 5.1.** Jan NAT data **$490** (10.9 TB). Endpoints ~$66/mo; if 2–4 TB is API traffic, **net savings ~$40–$110/mo**. |
| **CloudWatch log retention** | Shorten retention where you don't need long-term logs (e.g. 90 → 30 or 30 → 14 days for non-audit logs). | CloudWatch was ~\$306/mo (Jan); lower retention reduces storage and can reduce cost. |
| **EBS and snapshots** | Right-size volumes (gp3 is cheaper than gp2), delete **unattached** volumes and old snapshots (e.g. Trusted Advisor or describe-volumes/snapshots). "EC2 – Other" (~\$895/mo) includes EBS. | **§ 5.1.** 36 snapshots, 4,086 GB; 2023 = 136 GB. Jan snapshot cost $69; 0 unattached. Deleting 2023 snapshots ~$7/mo. Small win. |
| **Fargate Graviton** | Run Fargate tasks on ARM (Graviton) if your images support it. | Lower \$/vCPU than x86 Fargate; requires image rebuild and compatibility check. |
| **NAT Gateway** | Reduce to 1–2 NATs for non-prod, or use NAT instances for dev/stage. | Jan: **$490** data processing (10.9 TB) + **$301** hours (3 NATs). VPC endpoints (above) reduce data; fewer NATs or NAT instances reduce hours. |
| **Polly / MediaConvert** | Polly (~\$1k/mo) and MediaConvert (~\$37): optimize usage (caching, job settings) or reserved capacity if volume is high. | MediaConvert is smaller but optimizable. |
| **AWS Credits** | If you're eligible (e.g. startup programs, education, nonprofit), apply for AWS credits. | Can offset a portion of spend for a period; no commitment. |

---

**Summary:** **Compute Savings Plan (1-year, No Upfront)** + **RDS** and **ElastiCache Reserved Instances (1-year, No Upfront)** + **CloudFront Security Savings Bundle (1-year)** → **~$1,071–$1,108/month** saved, $0 upfront. Other opportunities: EC2 RIs, NAT, Config, Support, Polly, EFS, and § 5.