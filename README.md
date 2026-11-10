# Three-Tier Student Management System on AWS

Spring Boot 3 / Java 17 microservice → Docker → EC2 (public subnet) → RDS PostgreSQL (private subnets),
shipped by a GitHub Actions DevSecOps pipeline (Maven → SonarCloud → Trivy → ECR via OIDC).

## 1. Architecture

```
                         Internet
                            │
                  ┌─────────┴─────────┐
                  │  Internet Gateway │
                  └─────────┬─────────┘
┌───────────────────────────┼───────────────── VPC 10.0.0.0/16 ──────────────┐
│  Public RT: 0.0.0.0/0→IGW │                                                 │
│  ┌────────────────────────┴───────────┐                                     │
│  │ Public subnet 10.0.1.0/24  (AZ-a)  │                                     │
│  │  EC2 t3.micro + Docker             │                                     │
│  │  container: Spring Boot :8080      │   App-SG: 22 ← admin IP /32         │
│  │  (non-root UID 10001)              │           8080 ← 0.0.0.0/0          │
│  └────────────────────┬───────────────┘                                     │
│                       │ TCP 5432 (TLS, verify-full)                         │
│  Private RT: local only (no IGW route)                                      │
│  ┌──────────────────┐ │ ┌──────────────────┐   DB-SG: 5432 ← App-SG only   │
│  │ 10.0.2.0/24 AZ-a │◄┴►│ 10.0.3.0/24 AZ-b │   Publicly accessible: No     │
│  │  RDS PostgreSQL  │   │  (subnet-group   │   rds.force_ssl = 1           │
│  │  db.t4g.micro    │   │   second AZ)     │   Encrypted storage           │
│  └──────────────────┘   └──────────────────┘                               │
└─────────────────────────────────────────────────────────────────────────────┘

GitHub push to main → build+test → SonarCloud gate → docker build (tag=SHA) → Trivy → OIDC → ECR
```

Key design decisions
- **RDS secrets**: `--manage-master-user-password` generates the password in Secrets Manager. It never appears in code, the pipeline, or shell history. The EC2 role can read only that one secret.
- **No long-lived AWS keys in GitHub**: OIDC role trusted only for `repo:<owner>/<repo>:ref:refs/heads/main`, allowed only ECR push on one repository.
- **ECR**: immutable tags (SHA), scan-on-push, encrypted.
- **TLS to DB**: `rds.force_ssl=1` on the server *and* `sslmode=verify-full` with the RDS CA bundle baked into the image on the client.
- **Container hardening**: non-root user, read-only root FS, `--cap-drop ALL`, `no-new-privileges`, memory/PID limits, IMDSv2 required on EC2.

## 2. Repository layout

```
pom.xml  Dockerfile  .github/workflows/devsecops.yml
src/main/java/com/example/sms/{model,dto,repository,service,web,exception}
src/main/resources/{application.yml, db/migration/V1__create_students.sql}
src/test/java/...            (service + controller tests)
infra/provision.sh           VPC, subnets, IGW, RTs, SGs, RDS, IAM, EC2
infra/ci-bootstrap.sh        ECR repo, GitHub OIDC provider, push role
deploy/deploy.sh             runs on EC2: pull from ECR, start container
```

## 3. Step-by-step

### 3.1 Prerequisites
AWS CLI v2 configured (`aws configure`), an EC2 key pair (`aws ec2 create-key-pair --key-name sms-key --query KeyMaterial --output text > sms-key.pem && chmod 400 sms-key.pem`), a GitHub repo, a SonarCloud account.

### 3.2 Build the AWS infrastructure
```bash
export REGION=ap-south-1
export ADMIN_CIDR="$(curl -s https://checkip.amazonaws.com)/32"
export KEY_NAME=sms-key
./infra/provision.sh
```
Check `aws rds describe-db-engine-versions --engine postgres --query 'DBEngineVersions[].EngineVersion'` first; if `--engine-version 16` is rejected in your region, use an exact 16.x or 15.x version from that list.
If your account has no default-VPC quirks or AZ restrictions, nothing else needs changing. If `${REGION}a/b` is unavailable to your account, edit `AZ_A/AZ_B`.

### 3.3 One-time CI bootstrap (ECR + OIDC)
```bash
GITHUB_REPO=<owner>/<repo> ./infra/ci-bootstrap.sh
```
Add in GitHub → Settings → Secrets and variables → Actions:

| Type | Name | Value |
|---|---|---|
| Secret | `AWS_ROLE_ARN` | printed by the script |
| Secret | `SONAR_TOKEN` | SonarCloud → My Account → Security |
| Variable | `SONAR_ORGANIZATION` | your SonarCloud organization key |
| Variable | `SONAR_PROJECT_KEY` | your SonarCloud project key |

In SonarCloud, import the repo and, for a CI-driven analysis, disable "Automatic Analysis". The default "Sonar way" Quality Gate is enforced by `sonar.qualitygate.wait=true`.

### 3.4 Run the pipeline
`git push origin main`. Pipeline order: build/test → SonarCloud gate → image build (`student-service:<sha>`) → Trivy (fails on fixed CRITICAL/HIGH) → OIDC login → push to ECR.
If Trivy fails on a base-image CVE, bump the `eclipse-temurin` tag/rebuild, or on a dependency CVE bump the Spring Boot version. Avoid blanket ignores.

### 3.5 Deploy on EC2
```bash
source infra/infra.env
ssh -i sms-key.pem ec2-user@$PUBLIC_IP
# copy deploy/deploy.sh to the instance (scp), then on the instance:
export AWS_REGION=ap-south-1
export ECR_REGISTRY=<account-id>.dkr.ecr.ap-south-1.amazonaws.com
export IMAGE_TAG=<full git commit sha>
export DB_HOST=<from infra.env>  DB_SECRET_ARN=<from infra.env>
./deploy.sh
docker logs -f student-service      # Flyway should create the schema on first start
```
If `docker` is not found, wait about a minute after launch for user-data to finish (`sudo tail /var/log/cloud-init-output.log`).

### 3.6 Test the API (student schema)
```bash
BASE=http://<PUBLIC_IP>:8080/api/v1/students
curl -i -X POST $BASE -H 'Content-Type: application/json' -H 'X-Actor-Id: HR_ADMIN_01' -d '{
 "personalInformation":{"studentNumber":"STU-2026-1042","nic":"200312345678","fullName":"Akalanka Senarath Bandara",
  "initialsWithName":"A.S. Bandara","dob":"2003-05-12","gender":"Male","address":"45/A, Temple Road, Kandy, Sri Lanka",
  "mobile":"+94712345678","personalEmail":"akalanka.personal@gmail.com","universityEmail":"akalanka.b@ou.ac.lk"},
 "academicDetails":{"faculty":"Faculty of Engineering Technology","department":"Electrical and Computer Engineering",
  "programme":"BSc in Software Engineering","enrolmentType":"Part-time","enrolledDate":"2026-01-15","academicLevel":"Level 6","studentStatus":"ACTIVE"},
 "academicAdvisor":{"advisorStaffId":"STAFF-0457","advisorName":"Chaminda Perera","advisorEmail":"chaminda.p@ou.ac.lk","advisorMobile":"+94771234567"}}'

curl $BASE/STU-2026-1042                       # read (auditMetadata filled by server)
curl "$BASE?page=0&size=10"                     # list
curl -X PUT $BASE/STU-2026-1042 -H 'Content-Type: application/json' -H 'X-Actor-Id: HR_ADMIN_02' -d @updated.json   # sets updatedBy/updatedAt
curl -i -X DELETE $BASE/STU-2026-1042          # 204
curl http://<PUBLIC_IP>:8080/actuator/health
```
Status codes: 201 created, 400 validation (field → message map), 404 unknown student, 409 duplicate student number / NIC / university email.
`auditMetadata` is server-controlled: `insertedBy` comes from the `X-Actor-Id` header (default `SYSTEM`), timestamps are UTC, and `updatedBy/updatedAt` stay `null` until the first update.

## 4. Verification evidence checklist (screenshots for the assessment)

| Requirement | Command / console view |
|---|---|
| VPC CIDR, subnets, AZs | `aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID --query 'Subnets[].[CidrBlock,AvailabilityZone]'` |
| Public RT has IGW route, private RT does not | `aws ec2 describe-route-tables --route-table-ids $PUB_RT $PRIV_RT` |
| DB subnet group spans 2 AZs | `aws rds describe-db-subnet-groups --db-subnet-group-name sms-db-subnets` |
| RDS not public, encrypted, PG 15/16 | `aws rds describe-db-instances --db-instance-identifier sms-db --query 'DBInstances[0].[PubliclyAccessible,StorageEncrypted,EngineVersion,DBInstanceClass]'` |
| DB-SG only from App-SG | `aws ec2 describe-security-groups --group-ids $DB_SG --query 'SecurityGroups[0].IpPermissions'` |
| SSL enforced | on EC2: connect with `psql "host=$DB_HOST dbname=students user=dbadmin sslmode=disable"` must be **rejected**; `sslmode=require` works |
| DB unreachable from internet | `nc -vz $DB_HOST 5432` from your laptop times out |
| Container is non-root | `docker exec student-service id` → `uid=10001` |
| Pipeline | Actions run page (all green), SonarCloud dashboard with Quality Gate passed, Trivy table, ECR image tagged with SHA |

## 5. Known limitations (state them in your report)
- Single EC2 instance and Single-AZ RDS (Free Tier). The second AZ subnet exists to satisfy the subnet-group requirement and allow later Multi-AZ.
- HTTP only on port 8080, per the brief. For production, put an ALB with ACM certificate in front, and close 8080 to the internet.
- The API has no authentication. Production would validate a JWT (e.g. Spring Security + OIDC) and take `insertedBy` from the token instead of the `X-Actor-Id` header.
- The app uses the RDS master credentials. Production would create a least-privilege application role (`CREATE ROLE sms_app ...`) and keep the master secret for migrations only.
- No NAT gateway, so EC2 reaches AWS APIs and ECR over the IGW. Interface VPC endpoints are the hardened alternative.
- Free Tier has time and size limits, and a public IPv4 address is billed hourly. Check current pricing.

## 6. Billing alert and teardown (FinOps)
```bash
ALERT_EMAIL=you@example.com ./infra/billing-alert.sh   # do this BEFORE provisioning
./infra/teardown.sh                                    # after the viva; prints a verification block to screenshot
```
`teardown.sh` terminates EC2, deletes RDS (no final snapshot), the subnet and parameter groups, IAM role and profile, security groups, route tables, IGW, subnets, VPC and the ECR repository, then lists any leftover resources.
Keep EC2/RDS running until your viva slot is finished. Re-create them with `provision.sh` if you need to re-demo.
