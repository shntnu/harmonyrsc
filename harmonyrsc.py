import sys
import numpy as np
import pandas as pd
import anndata
import rapids_singlecell as rsc

# Configuration
N_PCA_COMPONENTS = 300

# Load data
input_path = sys.argv[1] if len(sys.argv) > 1 else "../jump-profiling-recipe/outputs/compound_DL_CPCNN_no_source7_gpu_public/profiles_dropna_var_mad_int_featselect.parquet"
output_path = sys.argv[2] if len(sys.argv) > 2 else "../jump-profiling-recipe/outputs/compound_DL_CPCNN_no_source7_gpu/profiles_dropna_var_mad_int_featselect_harmonyrsc.parquet"
batch_key = sys.argv[3] if len(sys.argv) > 3 else "Metadata_Source"

df = pd.read_parquet(input_path)

# Split features and metadata
meta = df[[c for c in df.columns if c.startswith("Metadata_")]].copy()
# Convert string columns to categorical
for col in meta.columns:
    if meta[col].dtype == 'object':
        meta[col] = meta[col].astype('category')

# Create meaningful index from Source, Plate, and Well columns
meta.index = (meta['Metadata_Source'].astype(str) + ':' +
              meta['Metadata_Plate'].astype(str) + ':' +
              meta['Metadata_Well'].astype(str))

feats = df[[c for c in df.columns if not c.startswith("Metadata_")]].values

# Handle NaN values
feats = np.nan_to_num(feats, nan=0.0)

# Create AnnData with explicit string index
adata = anndata.AnnData(X=feats, obs=meta)

print(f"Original shape: {adata.shape}")

# Run PCA first
rsc.tl.pca(adata, n_comps=N_PCA_COMPONENTS)
print(f"PCA complete: {adata.obsm['X_pca'].shape}")


# Run harmony on PCA coordinates (use GEMM to avoid CUDA alignment issues)
rsc.pp.harmony_integrate(adata, key=batch_key, use_gemm=True, n_clusters=300, max_iter_harmony=20)

print(f"Harmony complete: {adata.obsm['X_pca_harmony'].shape}")

# Save harmonized data back to parquet
# Create DataFrame with harmonized features
harmony_features = adata.obsm['X_pca_harmony']
harmony_cols = [f"harmony_{i+1}" for i in range(harmony_features.shape[1])]
harmony_df = pd.DataFrame(harmony_features, columns=harmony_cols, index=adata.obs.index)

# Add original metadata columns
for col in adata.obs.columns:
    harmony_df[col] = adata.obs[col].values

# Save to parquet
harmony_df.to_parquet(output_path)
print(f"Saved harmonized data to: {output_path}")