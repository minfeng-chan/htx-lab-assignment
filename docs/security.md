# Task 5 - Security Considerations

Proposed controls to reduce the impact of a breach.

## 1. Contain a breach between AWS and the data centre

- Isolate the adapter in a dedicated subnet/VLAN behind a firewall. Block access to other data-centre systems except the specific legacy integration flow.
- Advertise only the adapter subnet over Direct Connect. Allow adapter-initiated HTTPS to the cloud API and return traffic; deny new AWS-initiated connections.
- Restrict adapter -> NLB to HTTPS 443 and EKS -> RDS to PostgreSQL 5432. Enforce the required NLB -> EKS rules too.
- Keep minimal data and no administrator credentials on the adapter. Segmentation limits lateral movement if it is compromised, but its CSV data and API secret still need protection.

## 2. Reduce data exposure

- Minimize copies: retain the legacy source, temporary upload, and target database. Delete adapter temporary files and S3 objects after a successful database commit. Keep failed files only for an agreed investigation period; exclude transaction contents from logs.
- Encrypt transit with HTTPS for API calls/uploads and verified TLS for database and internal service connections. Direct Connect alone does not encrypt traffic.
- Encrypt adapter disks, S3, and RDS storage. The data-centre team manages disk keys; AWS manages S3 encryption keys and RDS uses its configured KMS key. Restrict key access and protect database backups too.
- The platform team manages TLS certificate renewal and limits private-key access to the terminating workloads. Encryption complements access controls; it does not stop a compromised application reading authorized data.

## 3. Limit access and long-lived credentials

- Give each workload the minimum permissions: uploader can write the S3 `incoming/` prefix; processor can read/delete there and connect only as its specific database user. SQL grants restrict database operations.
- Use GitHub OIDC for CI/CD, IRSA for EKS workloads, and IAM database authentication for the processor. These use temporary credentials instead of stored AWS keys or database passwords.
- Scope role trust to the intended repository/environment or Kubernetes service account. Keep deployment roles separate from application roles.
- Store the remaining Keycloak client secret in the on-premises secret store, readable only by the adapter account. The integration team rotates/revokes it; never put secrets or tokens in Git or logs.

Network perimeter, narrowed route advertisements, and application controls still require implementation; the current architecture shows the broader on-premises network.
