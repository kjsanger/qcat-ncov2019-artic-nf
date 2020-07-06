#!/bin/bash

set -euo pipefail

usage() {
  cat 1>&2 << EOF
This is a wrapper to de-plex multiplexed Oxford Nanopore sequencing data
using qcat (https://github.com/kjsanger/qcat) and pass the de-plexed reads
to the ncov2019-artic-nf pipeline
(https://github.com/wtsi-team112/ncov2019-artic-nf)

Usage: $0 -i <input directory>
          -o <outout directory>
          [-h] [-v]
Options:
  -h  Print usage and exit.
  -i  The directory path where the input data for qcat are located. This
      directory must contain all of the multiplexed, compressed fastq files
      from basecalling.
  -o  The directory path where the output data from the pipeline are to be
      written.
  -v  Print verbose messages.

Example:
  qcat-ncov2019-artic-nf.sh -i /data/basecalled -o /data/output

This script finds resources in directories relative to its location.
The qcat Nextflow pipeline and configuration:

  ../share/nextflow/qcat/deplex-qcat.nf
  ../share/nextflow/qcat/sanger.config

The Artic Nextflow pipeline and configuration:

  ../share/nextflow/ncov2019-artic-nf/mainf.nf"
  ../share/nextflow/ncov2019-artic-nf/nextflow.config"
  ../share/nextflow/ncov2019-artic-nf/sanger.config"

The Artic pipeline requires a suitable Singularity image to be
available. By default it uses an image located at

  ../share/nextflow/ncov2019-artic-nf/artic-ncov2019-nanopore.sif

The image location may be changed by setting the environment variable
ARTIC_IMAGE to an alternative path.

The pipelines create data staging areas in TMPDIR, so if your data are
large, TMPDIR should be set to a location on an appropriate filesystem
e.g. Lustre

Author: <kdj@sanger.ac.uk>
EOF
}

INPUT_PATH=
OUTPUT_PATH=

while getopts "hi:o:v" option; do
  case "$option" in
    i)
        INPUT_PATH="$OPTARG"
        ;;
    o)
        OUTPUT_PATH="$OPTARG"
        ;;
    h)
        usage
        exit 0
        ;;
    v)
        set -x
        ;;
    *)
        usage
        echo "Invalid argument"
        exit 4
        ;;
  esac
done

shift $((OPTIND -1))

if [ -z "$INPUT_PATH" ] ; then
    usage
    echo -e "\nERROR:\n  A -i <input path> argument is required"
    exit 4
fi

if [ -z "$OUTPUT_PATH" ] ; then
    usage
    echo -e "\nERROR:\n  An -o <output path> argument is required"
    exit 4
fi

LOCATION=$(dirname "$(readlink -f "$0")")
LOCAL=$(dirname "$LOCATION")

QCAT_NF="$LOCAL/share/nextflow/qcat"
if [ ! -f "$QCAT_NF/deplex-qcat.nf" ] ; then
    echo -e "\nERROR:\n  Failed to find qcat Nextflow pipeline at $QCAT_NF"
    exit 5
fi

QCAT_OUTPUT=$(mktemp -d -t qcat.XXXXXXXX)
nextflow run "$QCAT_NF/deplex-qcat.nf" \
         -c "$QCAT_NF/nextflow.config" \
         -c "$QCAT_NF/sanger.config" \
         --batchSize 50 \
         --kit PBC096andrew \
         --trim \
         --input "$INPUT_PATH" --output "$QCAT_OUTPUT"

ARTIC_NF="$LOCAL/share/nextflow/ncov2019-artic-nf"
if [ ! -d "$ARTIC_NF" ] ; then
    echo -e "\nERROR:\n  Failed to find Artic Nextflow pipeline at $ARTIC_NF"
    exit 5
fi

ARTIC_IMAGE=${ARTIC_IMAGE:-"$ARTIC_NF/artic-ncov2019-nanopore.sif"}
if [ ! -f "$ARTIC_IMAGE" ] ; then
    echo -e "\nERROR:\n  Failed to find Artic Nextflow pipeline image at $ARTIC_IMAGE"
    exit 5
fi

ARTIC_PREFIX=artic
ARTIC_SCHEME=V3
ARTIC_OUTPUT=$(mktemp -d -t artic.XXXXXXXX)
nextflow run "$ARTIC_NF" \
         -c "$ARTIC_NF/nextflow.config" \
         -c "$ARTIC_NF/sanger.config" \
         -profile lsf,singularity,sanger \
         --container $ARTIC_NF/artic-ncov2019-nanopore.sif \
         --medaka --basecalled_fastq "$QCAT_OUTPUT" \
         --schemeVersion ${ARTIC_SCHEME} \
         --prefix ${ARTIC_PREFIX} \
         --outdir ${ARTIC_OUTPUT}

medaka_output_dir=${ARTIC_OUTPUT}/articNcovNanopore_sequenceAnalysisMedaka_articMinIONMedaka
plots_output_dir=${ARTIC_OUTPUT}/qc_plots
exec_output_dir=${ARTIC_OUTPUT}/pipeline_info

for d in ${QCAT_OUTPUT}/barcode??
do
    bc=$(basename -- "$d")
    mkdir -p "$OUTPUT_PATH/$bc"

    for f in ${medaka_output_dir}/${ARTIC_PREFIX}_${bc}.*
    do
        [ -f  "$f" ] && mv "$f" "$OUTPUT_PATH/$bc"
    done

    for f in ${plots_output_dir}/${ARTIC_PREFIX}_${bc}.*
    do
        [ -f "$f" ] && mv "$f" "$OUTPUT_PATH/$bc"
    done
done

if [ -d "$exec_output_dir" ]; then
    cp -r "$exec_output_dir" "$OUTPUT_PATH"
fi

rm -rf "$QCAT_OUTPUT"
rm -rf "$ARTIC_OUTPUT"
