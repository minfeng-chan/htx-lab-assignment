# Task 4 - Observability

## Monitoring and alerts

- **Central view:** Use CloudWatch Logs, dashboards, and alarms. Collect adapter logs with the CloudWatch agent and EKS metrics with Container Insights. Send telemetry over private connectivity; buffer adapter logs locally during outages. Configure private endpoints, DNS, and agent permissions as prerequisites.
- **Mode A - API:** Monitor request count, response time, HTTP errors, authentication failures, and NLB target health. Alert on sustained errors, slow responses, or unhealthy targets. Agree thresholds with the service owner.
- **Mode B - Batch:** Record file creation, upload, validation, and database completion. Monitor Job failures, processing time, and accepted/rejected row counts. Alert if the nightly file is missing or the import misses its agreed deadline, including when no success signal arrives.
- **Notification:** Send alarms to the support team through SNS. Keep credentials, tokens, and transaction contents out of logs.

## Correlation

- Generate a `request_id` at the adapter and carry it in HTTP headers and API logs.
- Assign a stable `batch_id` to each CSV. Record it in adapter/upload logs, S3 metadata, Job logs, and the database import record.
- Use UTC timestamps and search the shared ID to find the last successful stage. Full distributed tracing is not required for this design.

## Runbook - Failed nightly transfer

1. Find the expected batch and its last successful stage using `batch_id`.
2. Check the source file and adapter scheduler, then Direct Connect, DNS, TLS, and authentication.
3. Confirm the S3 upload; check Job logs for CSV validation failures and RDS connection errors.
4. Fix the cause. Check the import record before retrying with the same `batch_id`; use transactional loading and a unique batch record to prevent duplicates. Quarantine invalid files for correction.
5. Confirm committed row counts and completion, notify support, and close the incident. Retain failed input for investigation within the configured retention period.
