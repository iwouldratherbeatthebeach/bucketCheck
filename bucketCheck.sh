#!/bin/bash
# made with Splunk hugs

# Defaults
EARLIEST_FILTER=0
LATEST_FILTER=9999999999
SHOW_DIFF=false
BUCKET_DIR=""

# Function to convert relative time like -1d, -2w to epoch seconds
relative_to_epoch() {
    local input="$1"
    local number=${input:1:-1}
    local unit=${input: -1}
    local seconds_ago

    case "$unit" in
        d) seconds_ago=$((number * 86400)) ;;         # days
        w) seconds_ago=$((number * 7 * 86400)) ;;      # weeks
        m) seconds_ago=$((number * 30 * 86400)) ;;     # months (approx)
        y) seconds_ago=$((number * 365 * 86400)) ;;    # years (approx)
        *) echo "Invalid time format: $input"; exit 1 ;;
    esac

    date -u -d "@$(( $(date +%s) - seconds_ago ))" +%s
}

# Help message
usage() {
    echo "Usage: $0 [--earliest -1w] [--latest -1d] [--show-diff] /path/to/buckets"
    echo ""
    echo "Options:"
    echo "  --earliest <time>   Minimum acceptable earliest time (e.g., -1y, -30d, -2w)"
    echo "  --latest <time>     Maximum acceptable latest time (e.g., -1d, -6m)"
    echo "  --show-diff         Show the difference (seconds) between latest and earliest"
    exit 1
}

# Parse CLI arguments
while [[ "$1" ]]; do
    case "$1" in
        --earliest )
            shift
            EARLIEST_FILTER=$(relative_to_epoch "$1")
            ;;
        --latest )
            shift
            LATEST_FILTER=$(relative_to_epoch "$1")
            ;;
        --show-diff )
            SHOW_DIFF=true
            ;;
        -* )
            echo "Unknown option: $1"; usage ;;
        * )
            BUCKET_DIR="$1"
            ;;
    esac
    shift
done

# Validate bucket directory
if [ -z "$BUCKET_DIR" ] || [ ! -d "$BUCKET_DIR" ]; then
    echo "Error: Must provide a valid bucket directory."
    usage
fi

# Header
if $SHOW_DIFF; then
    printf "%-50s %-20s %-20s %-10s %-6s\n" "Bucket Name" "Latest (UTC)" "Earliest (UTC)" "Diff(s)" "Size"
else
    printf "%-50s %-20s %-20s %-6s\n" "Bucket Name" "Latest (UTC)" "Earliest (UTC)" "Size"
fi

# Process buckets
for bucket in "$BUCKET_DIR"/*; do
    bucket_name=$(basename "$bucket")

    # Match db_ or rb_ buckets
    if [[ "$bucket_name" =~ ^(db|rb)_([0-9]+)_([0-9]+)_[0-9]+(_.*)?$ ]]; then
        bucket_type="${BASH_REMATCH[1]}"
        latest_epoch="${BASH_REMATCH[2]}"
        earliest_epoch="${BASH_REMATCH[3]}"

        # Validate and filter
        if [[ $earliest_epoch -ge $EARLIEST_FILTER && $latest_epoch -le $LATEST_FILTER ]]; then
            latest_date=$(date -u -d "@$latest_epoch" +"%Y-%m-%d %H:%M:%S")
            earliest_date=$(date -u -d "@$earliest_epoch" +"%Y-%m-%d %H:%M:%S")
            size=$(du -sh "$bucket" 2>/dev/null | cut -f1)
            diff=$((latest_epoch - earliest_epoch))

            if $SHOW_DIFF; then
                printf "%-50s %-20s %-20s %-10s %-6s\n" "$bucket_name" "$latest_date" "$earliest_date" "$diff" "$size"
            else
                printf "%-50s %-20s %-20s %-6s\n" "$bucket_name" "$latest_date" "$earliest_date" "$size"
            fi
        fi
    fi
done
