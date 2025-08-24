#!/bin/bash

# Usage: ./run_compare.sh file1.csv file2.csv

if [ $# -ne 2 ]; then
    echo "Usage: $0 <file1.csv> <file2.csv>"
    exit 1
fi

FILE1="$1"
FILE2="$2"

# Create a temporary SQL file with the parameters substituted
cat > /tmp/compare_temp.sql << 'EOF'
-- Build once, reuse across statements
CREATE TEMP VIEW j AS
SELECT
  s1.Metadata_JCP2022,
  s1.mean_average_precision  AS map_set1,
  s2.mean_average_precision  AS map_set2,
  s1.below_p                 AS set1_below_p,
  s2.below_p                 AS set2_below_p,
  s1.below_corrected_p       AS set1_below_corr_p,
  s2.below_corrected_p       AS set2_below_corr_p
EOF

echo "  FROM read_csv_auto('$FILE1') AS s1" >> /tmp/compare_temp.sql
echo "  JOIN read_csv_auto('$FILE2') AS s2" >> /tmp/compare_temp.sql
echo "  USING (Metadata_JCP2022);" >> /tmp/compare_temp.sql

cat >> /tmp/compare_temp.sql << 'EOF'

CREATE TEMP VIEW diffs AS
SELECT
  ABS(map_set1 - map_set2)                                    AS map_diff,
  (ABS(map_set1 - map_set2) / NULLIF(map_set2, 0)) * 100.0 AS percent_diff
FROM j;

.print 'Step 1: Row/ID sanity check'
SELECT COUNT(*) AS total_rows, COUNT(*) AS matching_ids FROM j;

.print 'Step 2: MAP difference buckets'
SELECT
  COUNT(*) FILTER (WHERE map_diff < 0.001)   AS diff_less_0_001,
  COUNT(*) FILTER (WHERE map_diff < 0.01)    AS diff_less_0_01,
  COUNT(*) FILTER (WHERE map_diff < 0.1)     AS diff_less_0_1,
  COUNT(*) FILTER (WHERE map_diff >= 0.1)    AS diff_greater_0_1,
  COUNT(*) FILTER (WHERE percent_diff < 1)   AS percent_diff_less_1,
  COUNT(*) FILTER (WHERE percent_diff < 5)   AS percent_diff_less_5,
  COUNT(*) FILTER (WHERE percent_diff >= 10) AS percent_diff_greater_10
FROM diffs;

.print 'Step 3: P-value agreement'
SELECT
  'P-value Agreement' AS metric,
  COUNT(*)                                                AS total,
  COUNT(*) FILTER (WHERE set1_below_p = set2_below_p)   AS same_significance,
  COUNT(*) FILTER (WHERE set1_below_p <> set2_below_p)  AS different_significance,
  COUNT(*) FILTER (WHERE set1_below_corr_p = set2_below_corr_p)  AS same_corrected_significance,
  COUNT(*) FILTER (WHERE set1_below_corr_p <> set2_below_corr_p) AS different_corrected_significance
FROM j;

-- Optional cleanup
DROP VIEW diffs;
DROP VIEW j;
EOF

# Run DuckDB with the temporary SQL file
duckdb < /tmp/compare_temp.sql

# Clean up
rm /tmp/compare_temp.sql
