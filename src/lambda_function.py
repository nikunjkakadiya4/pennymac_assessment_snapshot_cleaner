"""Delete  AWS account's EBS snapshots older than RETENTION_DAYS (from env, default 365)."""

import json
import logging
import os
from datetime import datetime, timedelta, timezone

import boto3
from botocore.exceptions import BotoCoreError, ClientError

# Lambda sends handler output to CloudWatch Logs; INFO is enough for ops visibility.
logging.getLogger().setLevel(logging.INFO)
log = logging.getLogger()

# Regional EC2 API client (uses the Lambda execution role in the deployed region).
ec2 = boto3.client("ec2")

# Default age threshold when the invoke payload does not override retention_days.
DEFAULT_DAYS = int(os.environ.get("RETENTION_DAYS", "365"))


def handler(event, context):
    # EventBridge may send {}, a string body, or a dict from the console / CLI.
    if not event:
        event = {}
    elif isinstance(event, str):
        event = json.loads(event) if event.strip() else {}

    # Optional per-invoke override, e.g. {"retention_days": 30} for a one-off test.
    days = int(event.get("retention_days", DEFAULT_DAYS))
    # Snapshots with StartTime >= cutoff are kept; older ones are delete candidates.
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)

    deleted = []
    errors = []
    kept = 0  # Count of snapshots still inside the retention window (not listed in "deleted").

    log.info("Snapshot cleanup: retention_days=%s cutoff=%s", days, cutoff.isoformat())

    # OwnerIds=["self"] limits to this account; paginate in case there are many snapshots.
    try:
        pages = ec2.get_paginator("describe_snapshots").paginate(OwnerIds=["self"])
    except (ClientError, BotoCoreError) as e:
        log.exception("Could not list snapshots")
        return {"ok": False, "error": str(e), "deleted": [], "errors": []}

    for page in pages:
        for s in page.get("Snapshots", []):
            start = s["StartTime"]
            if start.tzinfo is None:
                start = start.replace(tzinfo=timezone.utc)

            if start >= cutoff:
                kept += 1
                continue

            sid = s["SnapshotId"]
            log.info("Deleting snapshot %s (started %s)", sid, start.isoformat())
            try:
                ec2.delete_snapshot(SnapshotId=sid)
                deleted.append(sid)
            except (ClientError, BotoCoreError) as e:
                # e.g. snapshot in use by an AMI — log and continue with the rest.
                log.warning("Could not delete %s: %s", sid, e)
                errors.append({"snapshot_id": sid, "message": str(e)})

    log.info("Finished: deleted=%s kept=%s errors=%s", len(deleted), kept, len(errors))
    return {
        "ok": True,
        "retention_days": days,
        "cutoff_utc": cutoff.isoformat(),
        "deleted_count": len(deleted),
        "skipped_in_window_count": kept,
        "error_count": len(errors),
        "deleted": deleted,
        "errors": errors,
    }
