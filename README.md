# 🪣 Splunk Bucket Inspector

`bucketCheck.sh` is a lightweight Bash script that parses Splunk bucket directories to show the **event time ranges**, **bucket sizes**, and optionally the **time span** between the newest and oldest events.

Perfect for checking when buckets will freeze or for cleaning up stale data.

---

## Features

- Parses Splunk bucket names (format: `db_<latest_epoch>_<earliest_epoch>_<id>`)
- Converts epoch times to human-readable UTC
- Filters buckets by relative time ranges (e.g., `-1d`, `-1w`, `-6m`, `-1y`)
- Displays optional difference in seconds between latest and earliest
- Shows bucket size (`du -sh`)

---

## Usage

```
./bucketCheck.sh [OPTIONS] /path/to/splunk/index/db/
```

### Options

| Option         | Description                                                             |
|----------------|-------------------------------------------------------------------------|
| `--earliest`   | Minimum acceptable **earliest** time (e.g., `-1y`, `-2w`, `-30d`)        |
| `--latest`     | Maximum acceptable **latest** time (e.g., `-1d`, `-6m`)                 |
| `--show-diff`  | Shows the number of seconds between the latest and earliest event       |

---

## Examples

List all buckets modified in the last **week to day** range:

```
./bucketCheck.sh --earliest -1w --latest -1d --show-diff /opt/splunk/data/mediadb/db/
```

List all buckets that contain **data newer than 6 months ago**:

```
./bucketCheck.sh --earliest -6m /opt/splunk/data/mediadb/db/
```

---

## Example Output

```
Bucket Name                       Latest (UTC)         Earliest (UTC)       Diff(s)   Size
db_1691030455_1691030449_60       2023-08-03 02:40:55  2023-08-03 02:40:49  6         5.2M
db_1730487699_1730455110_39       2024-11-01 19:01:39  2024-11-01 09:58:30  32789     132K
```

---

## Notes

- This script assumes the bucket naming format follows Splunk’s convention:
  `db_<latest_epoch>_<earliest_epoch>_<id>`
- Compatible with most Linux distributions (tested on CentOS and Ubuntu)

---
