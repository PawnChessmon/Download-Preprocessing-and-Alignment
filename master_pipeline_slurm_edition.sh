#!/bin/bash
#SBATCH --job-name=Master_Pipeline
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=55G
#SBATCH --time=96:00:00
#SBATCH --output=master_pipeline.log
#SBATCH --error=master_pipeline.err

# Strict mode: If any step fails, the script immediately stops.
set -euo pipefail

# Navigate to working directory (raw_data)
cd $SLURM_SUBMIT_DIR

echo "Starting Sequential Processing Pipeline: $(date)"

# -----------------------------------------------------------------------------
# STEP 1: Environment & Directories
# -----------------------------------------------------------------------------
source ~/miniforge3/etc/profile.d/conda.sh
conda activate fluke_qc

FILEREPORT="filereport_read_run_ERP134887.tsv"
REF="ncbi_dataset/data/GCA_964213165.1/GCA_964213165.1_htOpiVive1.1_genomic.fna"

# Setup directories
DIR_RAW="Genomes"
DIR_FASTQC="qc_raw_fastqc"
DIR_FASTP="fastp_reads"
DIR_ALIGN="alignment"

mkdir -p "$DIR_RAW" "$DIR_FASTQC" "$DIR_FASTP" "$DIR_ALIGN"

# -----------------------------------------------------------------------------
# STEP 2: Pre-index Reference Genome (Only runs once)
# -----------------------------------------------------------------------------
if [ ! -f "${REF}.mmi" ]; then
    echo "Indexing reference genome..."
    minimap2 -d "${REF}.mmi" "$REF"
fi

# -----------------------------------------------------------------------------
# STEP 3: Sequential Processing Loop
# -----------------------------------------------------------------------------
# Extract all accessions
mapfile -t ACCESSIONS < <(awk -F'\t' 'NR>1 {print $1}' "$FILEREPORT")

for ACC in "${ACCESSIONS[@]}"; do
    if [[ -z "$ACC" ]]; then continue; fi

    BAM_FINAL="$DIR_ALIGN/${ACC}_aligned.sorted.bam"
    
    # Skip entirely if the final BAM is already created
    if [[ -f "$BAM_FINAL" ]]; then
        echo "--- Skipping ${ACC}: Final BAM already exists ---"
        continue
    fi

    echo "========== Processing ${ACC} =========="
    
    RAW_R1="$DIR_RAW/${ACC}_1.fastq.gz"
    RAW_R2="$DIR_RAW/${ACC}_2.fastq.gz"

    # A. FETCH SRA (Only if the .fastq.gz doesn't already exist)
    if [[ ! -f "$RAW_R1" ]]; then
        echo "Fetching SRA for ${ACC}..."
        prefetch --max-size 100G "${ACC}"
        fasterq-dump --split-files --threads 8 "${ACC}"
        
        # Compress and move to the raw directory
        gzip -v "${ACC}"*.fastq
        mv "${ACC}"*.fastq.gz "$DIR_RAW/"
        
        # Clean up the prefetch SRA folder
        rm -rf "${ACC}"
    else
        echo "Found existing downloaded data for ${ACC}. Proceeding to QC."
    fi

    # B. FASTQC
    echo "Running FastQC..."
    fastqc -t 8 -o "$DIR_FASTQC" "$RAW_R1" "$RAW_R2"

    # C. TRIMMING (fastp)
    echo "Trimming with fastp..."
    TRIM_R1="$DIR_FASTP/${ACC}_1_trimmed.fq.gz"
    TRIM_R2="$DIR_FASTP/${ACC}_2_trimmed.fq.gz"
    
    fastp \
        -i "$RAW_R1" -I "$RAW_R2" \
        -o "$TRIM_R1" -O "$TRIM_R2" \
        --detect_adapter_for_pe --thread 8 \
        -h "$DIR_FASTP/${ACC}_fastp.html" \
        -j "$DIR_FASTP/${ACC}_fastp.json"

    # >>> STORAGE SAVE: Delete massive raw data the moment trimming succeeds <<<
    echo "Trimming successful. Deleting raw FASTQ files..."
    rm -v "$RAW_R1" "$RAW_R2"

    # D. ALIGNMENT (minimap2)
    echo "Aligning reads to reference..."
    minimap2 -a -x sr -t 8 -R "@RG\tID:${ACC}\tSM:${ACC}\tPL:ILLUMINA" "${REF}.mmi" "$TRIM_R1" "$TRIM_R2" | \
    samtools sort -@ 8 -T "./${ACC}_tmp" -o "$BAM_FINAL" -
    
    samtools index "$BAM_FINAL"
    samtools flagstat "$BAM_FINAL" > "$DIR_ALIGN/${ACC}_alignment_stats.txt"

    # >>> STORAGE SAVE: Delete trimmed intermediate files once BAM succeeds <<<
    echo "Alignment successful. Deleting trimmed FASTQ files..."
    rm -v "$TRIM_R1" "$TRIM_R2"
    
    echo "========== Finished ${ACC} =========="
done

# -----------------------------------------------------------------------------
# STEP 4: Aggregate Quality Reports
# -----------------------------------------------------------------------------
echo "Running MultiQC to aggregate all reports..."
multiqc "$DIR_FASTQC" "$DIR_FASTP" "$DIR_ALIGN" -o "MultiQC_Report"

echo "Pipeline complete: $(date)"
