# Opisthorchis viverrini WGS Processing Pipeline

## Overview
This repository contains the accession lists and automated HPC master scripts used to download, preprocess, and align *Opisthorchis viverrini* whole-genome sequencing (WGS) data. 

The pipeline is explicitly designed for high-performance computing (HPC) environments with strict storage quotas (e.g., <500 GB scratch limits). It utilizes a sequential, "self-cleaning" architecture that fully processes one isolate from raw SRA download through to a sorted BAM file, immediately deleting massive intermediate raw files (`.fastq.gz`) before initiating the next sample.

## Scripts Provided
* **`Lao_master_pipeline.pbs`**: Master pipeline configured for PBS job schedulers.
* **`Lao_master_pipeline_slurm_edition.sh`**: Master pipeline configured for Slurm workload managers.

**Pipeline Tools Integrated:** `sra-tools` (prefetch/fasterq-dump) -> `fastqc` -> `fastp` (trimming) -> `minimap2` (alignment) -> `samtools` (sort/index).

## Datasets
The `accessions/` directory contains the SRA run accessions for **37 total samples** used in this project, categorized by sequencing technology and geographic origin:

### 1. Short-Read WGS (Illumina)
* **Lao Isolates (`lao_accessions.tsv`):** 32 WGS samples collected from Laos. 
* **Thailand Isolates (`thai_accessions.tsv`):** 4 WGS samples collected from Thailand.

### 2. Long-Read Reference Data (PacBio)
* **Reference Strain (`ref_accession.tsv`):** 1 PacBio long-read sample. This is the raw sequence data originally used to assemble the reference genome (`GCA_964213165.1`) utilized in this pipeline's alignment step.

## Usage
Both scripts require a conda/mamba environment with the necessary bioinformatics tools installed. 

1. Clone this repository.
2. Build the environment: `conda create -n fluke_qc -c bioconda sra-tools fastqc fastp minimap2 samtools multiqc`
3. Edit the `FILEREPORT` variable in the script to point to your desired `.tsv` accession list.
4. Submit the job to your respective cluster:
   * **PBS:** `qsub Lao_master_pipeline.pbs`
   * **Slurm:** `sbatch Lao_master_pipeline_slurm.sh`
