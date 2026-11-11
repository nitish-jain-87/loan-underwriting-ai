# From OCP + Helm to AWS: what you already know, and what the platform hid from you

**Who this is for:** you've deployed to OpenShift (on AWS) by filling in the right Helm values. A platform team owned everything underneath. This doc maps each concept you used to its AWS equivalent, then lists what you never had to touch, which is exactly what you'll learn in AWS-0 to AWS-2 and what interviewers probe.

**One-sentence version:** on OCP you configured *your app inside someone else's platform*. On AWS you **build the platform pieces yourself**: identity, network, load balancer, secrets, database, pipeline. We'll use **ECS Fargate**, not EKS. It's the same container ideas with no cluster to run, and it's where Kubernetes knowledge transfers most cheaply.

---

## 1. Concept map: what you used → what it is on AWS

| What you used on OCP / Helm | AWS equivalent (our setup) | What actually changes for you |
|---|---|---|
| The Helm chart the infra team gave you | **Terraform module**, which you'll write | You now write the template, not just the values |
| `values.yaml` (image tag, replicas, env, resources) | Terraform **variables** / `.tfvars` + the **ECS task definition** | Same idea: parameters fed into a template |
| `helm upgrade` / `helm rollback` | `terraform apply` + **ECS rolling deployment** (with the deployment circuit breaker for auto-rollback) | Infra changes and app rollouts become two separate concerns |
| OCP project / namespace | **ECS cluster + service**. The real isolation boundary is the **AWS account** and the **VPC** | On AWS, the strongest isolation is a separate account, not a namespace |
| `Deployment` / `DeploymentConfig` | **ECS Service** (keeps N tasks running, does rollouts) | — |
| Pod spec / container spec | **Task definition** (image, CPU/memory, env, secrets, ports, health check, log config) | One JSON document holds what was spread across your chart |
| Pod | **Task** | — |
| `resources.requests/limits` | Task **CPU/memory** (Fargate supports fixed size combinations) | You pay for exactly what you request |
| Worker nodes | **None (Fargate)**. AWS runs the hosts | No node pools, no node patching |
| Internal registry / ImageStream / Quay / Artifactory | **ECR** (Elastic Container Registry) | Image scanning can be turned on per repository |
| `Route` / `Ingress` | **ALB** (Application Load Balancer): listener → rules → **target group** | You now provision the load balancer, its TLS cert (**ACM**) and DNS (**Route 53**) yourself |
| `Service` (ClusterIP) | ALB target group, or ECS Service Connect / Cloud Map for service-to-service | — |
| Liveness / readiness probes | **Target group health check** (ALB decides about traffic) + **container health check** in the task definition (ECS decides about restarts) | Two health checks, two owners: the same split as readiness vs liveness |
| `HorizontalPodAutoscaler` | **ECS Service Auto Scaling** (target tracking on CPU, memory or request count) | — |
| `ConfigMap` | Plain env vars in the task definition, or **SSM Parameter Store** | — |
| `Secret` (often base64 in the cluster, managed by infra) | **Secrets Manager** (or SSM SecureString), injected through the task definition's `secrets` block | Encrypted with KMS, access controlled by IAM, rotation possible, every read audited in CloudTrail |
| `ServiceAccount` + RBAC | **IAM roles**. Two of them per task (see §3) | **Your biggest gap.** Learn this one properly |
| `NetworkPolicy` | **Security groups** (stateful, attached to each task's network interface) + NACLs (rarely needed) | Security groups reference *each other*: "RDS allows 5432 only from the app's SG" |
| Egress firewall / proxy | **NAT gateway** for internet egress from private subnets, **VPC endpoints** (PrivateLink) to reach AWS services without the internet | The NAT gateway is the classic surprise cost |
| Operator-managed Postgres / PVC | **RDS for PostgreSQL** (with the **pgvector** extension) | Backups, patching and failover are a setting, not a ticket |
| EFK / Splunk logging | **CloudWatch Logs** (the `awslogs` log driver in the task definition) | — |
| Prometheus / Grafana | **CloudWatch Metrics** (Micrometer has a CloudWatch registry), or Amazon Managed Prometheus/Grafana | — |
| Jenkins / Tekton owned by infra | **GitHub Actions** assuming an IAM role via **OIDC** | No stored AWS keys in CI. A common senior interview question |
| `oc login` / kubeconfig | `aws sso login` + named **profiles**. Credentials are short-lived (**STS**) | Never create IAM user access keys for yourself |
| `ResourceQuota` | **Service Quotas** + **AWS Budgets** alarms | On AWS, cost is your problem, not infra's |

---

## 2. What OCP hid from you (your real learning list)

1. **IAM.** Who or what can call which AWS API, on which resource. Policies, roles, trust relationships, least privilege.
2. **VPC networking.** Subnets (public vs private), route tables, internet gateway vs NAT gateway, security groups, VPC endpoints.
3. **Edge.** Load balancer, TLS certificates (ACM), DNS (Route 53).
4. **Managed data.** RDS sizing, backups, parameter groups, extensions such as pgvector.
5. **Identity in CI.** OIDC federation from GitHub to an IAM role.
6. **Cost.** Every resource has a meter running. Budgets, tagging, teardown.

That's the list AWS-0 to AWS-2 covers. It's also what separates "I deployed with a template" from "I can design and secure a deployment".

---

## 3. The one concept to understand before Week 6: two IAM roles per ECS task

| Role | Who uses it | What it allows in *our* system | OCP analogy |
|---|---|---|---|
| **Task execution role** | **ECS itself**, before and around your container | Pull the image from ECR, write logs to CloudWatch, **read the OpenAI key from Secrets Manager** to inject it | What the platform does for you (image pull secret, log shipping) |
| **Task role** | **Your Spring Boot app**, at runtime, through the AWS SDK | **Call Bedrock** (`InvokeModel` / `Converse` on specific model IDs only), read the S3 bucket of loan documents | The pod's ServiceAccount, with RBAC |

Your app never sees an AWS access key. The SDK picks up temporary credentials for the task role automatically. That's the AWS answer to the question you asked on Day 2 about where the API key lives: locally it's an env var, on AWS it's Secrets Manager, and for Bedrock there's no key at all, just the task role.

---

## 4. Where each piece lands in the plan

| Lesson | AWS content | OCP bridge |
|---|---|---|
| **AWS-0** (Week 2, 1.5 h) | Root MFA, IAM Identity Center user, `aws sso login`, budget alarm | `oc login` → SSO profiles. Quotas → Budgets |
| **AWS-1** (Week 4, 3 h) | **Bedrock** as the `bedrock` provider profile and fallback model. Task-role-style auth, data stays in your account and region | A new "backend service" your pod can call, gated by RBAC → IAM |
| **AWS-2** (Week 6, ~15 h) | Terraform: VPC (or the default VPC to start), ECR, ECS Fargate + ALB, RDS pgvector, Secrets Manager, two IAM roles, CloudWatch, GitHub OIDC deploy, teardown script | Every row of the §1 table, built by you instead of the infra team |

Each AWS lesson follows the course format: **concept (starting from the OCP equivalent) → practical build → interview questions with answers.** The consolidated interview bank at wrap-up then connects it all: a request traced from the ALB through ECS to Bedrock/OpenAI and RDS, with PII controls at every hop.
