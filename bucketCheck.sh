#!/usr/bin/env bash
set -euo pipefail

#####################################
# Defaults
#####################################
EARLIEST_FILTER=0
LATEST_FILTER=$(date +%s)
SHOW_DIFF=true
RAW_DIFF=false

#####################################
# Convert relative time (e.g. -1d, -2w) to epoch seconds
#####################################
relative_to_epoch() {
    local input="$1"
    if [[ ! "$input" =~ ^-([0-9]+)([dwmy])$ ]]; then
        echo "Invalid time format: $input" >&2
        exit 1
    fi
    local number=${BASH_REMATCH[1]}
    local unit_char=${BASH_REMATCH[2]}
    local unit
    case "$unit_char" in
        d) unit="day"   ;;
        w) unit="week"  ;;
        m) unit="month" ;;
        y) unit="year"  ;;
    esac
    date -u -d "$number $unit ago" +%s
}

#####################################
# Convert seconds to human‐readable e.g. "1d 3h 20m 15s"
#####################################
human_readable_diff() {
    local diff=$1
    local days=$(( diff/86400 ))
    local hours=$(( (diff%86400)/3600 ))
    local minutes=$(( (diff%3600)/60 ))
    local seconds=$(( diff%60 ))
    local out=""
    (( days   > 0 )) && out+="${days}d "
    (( hours  > 0 )) && out+="${hours}h "
    (( minutes> 0 )) && out+="${minutes}m "
    # always show seconds (or if everything else was zero)
    out+="${seconds}s"
    echo "$out"
}

#####################################
# Help / usage
#####################################
usage() {
    cat <<EOF >&2
Usage: $0 [--earliest <rel-time>] [--latest <rel-time>] [--show-diff] [--raw-diff] /path/to/buckets

Options:
  --earliest <time>   Only include buckets with earliest ≥ <time> (e.g. -1w, -30d)
  --latest   <time>   Only include buckets with latest   ≤ <time> (e.g. -1d, -6m)
  --show-diff         Show diff between latest & earliest (human‐readable by default)
  --raw-diff          Show diff in raw seconds instead of human‐readable
EOF
    exit 1
}

#####################################
# Parse args with getopt
#####################################
OPTIONS=$(getopt -o '' --long earliest:,latest:,show-diff,raw-diff -- "$@") || usage
eval set -- "$OPTIONS"

while true; do
    case "$1" in
        --earliest)
            EARLIEST_FILTER=$(relative_to_epoch "$2")
            shift 2
            ;;
        --latest)
            LATEST_FILTER=$(relative_to_epoch "$2")
            shift 2
            ;;
        --show-diff)
            SHOW_DIFF=true
            RAW_DIFF=false
            shift
            ;;
        --raw-diff)
            SHOW_DIFF=true
            RAW_DIFF=true
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            usage
            ;;
    esac
done

BUCKET_DIR=${1:-}
[[ -d "$BUCKET_DIR" ]] || { echo "Error: '$BUCKET_DIR' is not a directory" >&2; usage; }

#####################################
# Print header
#####################################
if $SHOW_DIFF; then
    if $RAW_DIFF; then
        printf "%-50s %-20s %-20s %-10s %-6s\n" \
            "Bucket Name" "Latest (UTC)" "Earliest (UTC)" "Diff(s)" "Size"
    else
        printf "%-50s %-20s %-20s %-15s %-6s\n" \
            "Bucket Name" "Latest (UTC)" "Earliest (UTC)" "Diff" "Size"
    fi
else
    printf "%-50s %-20s %-20s %-6s\n" \
        "Bucket Name" "Latest (UTC)" "Earliest (UTC)" "Size"
fi

#####################################
# Iterate & filter buckets
#####################################
for bucket in "$BUCKET_DIR"/*; do
    bucket_name=$(basename "$bucket")
    if [[ "$bucket_name" =~ ^(db|rb)_([0-9]+)_([0-9]+)_[0-9]+(_.*)?$ ]]; then
        latest_epoch=${BASH_REMATCH[2]}
        earliest_epoch=${BASH_REMATCH[3]}

        if (( earliest_epoch >= EARLIEST_FILTER && latest_epoch <= LATEST_FILTER )); then
            latest_date=$(date -u -d "@$latest_epoch" +"%Y-%m-%d %H:%M:%S")
            earliest_date=$(date -u -d "@$earliest_epoch" +"%Y-%m-%d %H:%M:%S")
            size=$(du -sh "$bucket" 2>/dev/null | cut -f1)

            if $SHOW_DIFF; then
                diff=$(( latest_epoch - earliest_epoch ))
                if $RAW_DIFF; then
                    diff_val=$diff
                else
                    diff_val=$(human_readable_diff "$diff")
                fi
                printf "%-50s %-20s %-20s %-15s %-6s\n" \
                    "$bucket_name" "$latest_date" "$earliest_date" "$diff_val" "$size"
            else
                printf "%-50s %-20s %-20s %-6s\n" \
                    "$bucket_name" "$latest_date" "$earliest_date" "$size"
            fi
        fi
    fi
done
