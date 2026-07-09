# *Opisthorchis viverrini* WGS Processing Pipeline

## Overview
This repository contains the accession lists and automated HPC master scripts used to download, preprocess, and align *Opisthorchis viverrini* whole-genome sequencing (WGS) data. 

The pipeline is explicitly designed for high-performance computing (HPC) environments with strict storage quotas (e.g., <500 GB scratch limits). It utilizes a sequential, "self-cleaning" architecture that fully processes one isolate from raw SRA download through to a sorted BAM file, immediately deleting massive intermediate raw files (`.fastq.gz`) before initiating the next sample.

## Scripts Provided
* **`master_pipeline.pbs`**: Master pipeline configured for PBS job schedulers.
* **`master_pipeline_slurm_edition.sh`**: Master pipeline configured for Slurm workload managers.

**Pipeline Tools Integrated:** `sra-tools` (prefetch/fasterq-dump) -> `fastqc` -> `fastp` (trimming) -> `minimap2` (alignment) -> `samtools` (sort/index).

## Datasets
The `accessions/` directory contains the SRA run accessions for **37 total samples** used in this project, categorized by sequencing technology and geographic origin:

### 1. Short-Read WGS (Illumina)
* **Lao Isolates (`lao_accessions.tsv`):** 32 WGS samples collected from Laos. 
* **Thailand Isolates (`thai_accessions.tsv`):** 4 WGS samples collected from Thailand.

### 2. Long-Read Reference Data (PacBio)
* **Reference Strain (`ref_accession.tsv`):** 1 PacBio long-read sample. This is the raw sequence data originally used to assemble the reference genome (`GCA_964213165.1`) utilized in this pipeline's alignment step.

## Prerequisites & Dependencies

This pipeline requires a Unix-based High-Performance Computing (HPC) environment equipped with a job scheduler (PBS/Torque or Slurm) and a Conda-based environment manager (Miniforge, Miniconda, or Anaconda).

### 1. Bioinformatics Tools
All core processing tools are available through the `bioconda` channel. The script assumes these are installed in a dedicated environment (e.g., `fluke_qc`).

* **SRA-Tools** (`sra-tools`): Required for downloading and extracting raw sequence data (`prefetch`, `fasterq-dump`).
* **FastQC** (`fastqc`): Required for raw read quality assessment.
* **fastp** (`fastp`): Required for adapter trimming and quality filtering.
* **Minimap2** (`minimap2`): Required for indexing the reference genome and aligning short reads.
* **SAMtools** (`samtools`): Required for BAM sorting, indexing, and alignment metric generation (`flagstat`).
* **MultiQC** (`multiqc`): Required to aggregate all individual QC and alignment logs into a single HTML report.

**Quick Install Command:**
```bash
conda create -n fluke_qc -c conda-forge -c bioconda sra-tools fastqc fastp minimap2 samtools multiqc -y
```


### 2. Required Input Files
The script operates in strict mode (`set -euo pipefail`) and will abort if the following input files are not present in the working directory prior to execution:

* **Accession List (`.tsv`):** A tab-separated values file containing the SRA run accessions. The script parses the first column and ignores the header row. (Update the `FILEREPORT` variable in the script to match your filename).
* **Reference Genome (`.fna` / `.fasta`):** An uncompressed reference genome file. The script will automatically build the `.mmi` index during its first run. (Update the `REF` variable in the script to point to this file path).

### 3. System Utilities
The pipeline relies on standard GNU core utilities typically pre-installed on Linux/Unix systems:
* `awk` (for TSV parsing)
* `gzip` (for storage-efficient compression)
* `wget` / `curl` (optional, for fetching reference datasets)
