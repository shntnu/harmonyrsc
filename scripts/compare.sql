-- Define file paths as variables
SET VARIABLE file1 = 'data/processed/copairs/runs/activity/jump_orf_harmonized/results/activity_map_results.csv';
SET VARIABLE file2 = 'data/processed/copairs/runs/activity/jump_orf/results/activity_map_results.csv';

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
  FROM read_csv_auto(getvariable('file1')) AS s1
  JOIN read_csv_auto(getvariable('file2')) AS s2
  USING (Metadata_JCP2022);

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

-- Step 1: Row/ID sanity check
-- ┌────────────┬──────────────┐
-- │ total_rows │ matching_ids │
-- │   int64    │    int64     │
-- ├────────────┼──────────────┤
-- │   112585   │    112585    │
-- └────────────┴──────────────┘
-- Step 2: MAP difference buckets
-- ┌─────────────────┬────────────────┬───────────────┬──────────────────┬─────────────────────┬─────────────────────┬─────────────────────────┐
-- │ diff_less_0_001 │ diff_less_0_01 │ diff_less_0_1 │ diff_greater_0_1 │ percent_diff_less_1 │ percent_diff_less_5 │ percent_diff_greater_10 │
-- │      int64      │     int64      │     int64     │      int64       │        int64        │        int64        │          int64          │
-- ├─────────────────┼────────────────┼───────────────┼──────────────────┼─────────────────────┼─────────────────────┼─────────────────────────┤
-- │      62767      │     103015     │    112227     │       358        │        9410         │        52790        │          28514          │
-- └─────────────────┴────────────────┴───────────────┴──────────────────┴─────────────────────┴─────────────────────┴─────────────────────────┘
-- Step 3: P-value agreement
-- ┌───────────────────┬────────┬───────────────────┬────────────────────────┬─────────────────────────────┬──────────────────────────────────┐
-- │      metric       │ total  │ same_significance │ different_significance │ same_corrected_significance │ different_corrected_significance │
-- │      varchar      │ int64  │       int64       │         int64          │            int64            │              int64               │
-- ├───────────────────┼────────┼───────────────────┼────────────────────────┼─────────────────────────────┼──────────────────────────────────┤
-- │ P-value Agreement │ 112585 │      111278       │          1307          │           111936            │               649                │
-- └───────────────────┴────────┴───────────────────┴────────────────────────┴─────────────────────────────┴──────────────────────────────────┘
