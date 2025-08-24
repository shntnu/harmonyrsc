# harmonyrsc

Quick POC for testing [Harmony batch correction](https://rapids-singlecell.readthedocs.io/en/latest/api/generated/rapids_singlecell.pp.harmony_integrate.html#rapids_singlecell.pp.harmony_integrate) from [rapids-singlecell](https://scanpy.readthedocs.io/en/stable/index.html) on morphological profiling data from the [JUMP](https://broad.io/jump) dataset.

## Installation

```bash
pixi install
```

## Test with JUMP data

Download test data:
```bash
mkdir -p data/raw/profiles
wget \
    https://cellpainting-gallery.s3.amazonaws.com/cpg0016-jump-assembled/source_all/workspace/profiles_assembled/ORF/v1.0b/profiles_wellpos_var_mad_int_featselect.parquet \
    -O data/raw/profiles/jump_orf.parquet
```

Run Harmony:
```bash
mkdir -p data/intermediate/profiles
pixi run python harmonyrsc.py \
    data/raw/profiles/jump_orf.parquet \
    data/intermediate/profiles/jump_orf_harmonized.parquet \
    Metadata_Batch
```

## Usage

```bash
python harmonyrsc.py <input.parquet> <output.parquet> <batch_column>
```

- `input.parquet`: Morphological profiles with metadata columns
- `output.parquet`: Harmonized features output
- `batch_column`: Metadata column to use for batch correction (e.g., "Metadata_Source")


```bash
mkdir -p data/external
wget \
    https://github.com/jump-cellpainting/datasets/releases/download/v0.12/jump_metadata.duckdb \
    -O data/external/jump_metadata.duckdb
```








