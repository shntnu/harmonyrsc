-- Build once, reuse across statements
CREATE TEMP VIEW j AS
SELECT
  g.Metadata_JCP2022,
  g.mean_average_precision  AS map_gpu,
  n.mean_average_precision  AS map_non_gpu,
  g.below_p                 AS gpu_below_p,
  n.below_p                 AS non_gpu_below_p,
  g.below_corrected_p       AS gpu_below_corr_p,
  n.below_corrected_p       AS non_gpu_below_corr_p
  FROM parquet_scan('/data/shsingh/GitHub/jump-profiling-recipe/outputs/compound_DL_CPCNN_no_source7_rsc/metrics/profiles_dropna_var_mad_int_featselect_harmonyrsc_map_nonrep.parquet') AS g
--   FROM parquet_scan('/data/shsingh/GitHub/jump-profiling-recipe/outputs/compound_DL_CPCNN_no_source7_gpu/metrics/profiles_dropna_var_mad_int_featselect_harmony_map_nonrep.parquet') AS g
  JOIN parquet_scan('/data/shsingh/GitHub/jump-profiling-recipe/outputs/compound_DL_CPCNN_no_source7/metrics/profiles_dropna_var_mad_int_featselect_harmony_map_nonrep.parquet') AS n
  USING (Metadata_JCP2022);

CREATE TEMP VIEW diffs AS
SELECT
  ABS(map_gpu - map_non_gpu)                                    AS map_diff,
  (ABS(map_gpu - map_non_gpu) / NULLIF(map_non_gpu, 0)) * 100.0 AS percent_diff
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
  COUNT(*) FILTER (WHERE gpu_below_p = non_gpu_below_p)   AS same_significance,
  COUNT(*) FILTER (WHERE gpu_below_p <> non_gpu_below_p)  AS different_significance,
  COUNT(*) FILTER (WHERE gpu_below_corr_p = non_gpu_below_corr_p)  AS same_corrected_significance,
  COUNT(*) FILTER (WHERE gpu_below_corr_p <> non_gpu_below_corr_p) AS different_corrected_significance
FROM j;

-- Optional cleanup
DROP VIEW diffs;
DROP VIEW j;