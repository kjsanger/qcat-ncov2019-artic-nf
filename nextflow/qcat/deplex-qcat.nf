params.input = './input'
params.output = './output'
params.batchSize = 10

params.kit = 'PBC096andrew'
params.minScore = 60
params.minReadLength = 100


// Batch the multiplexed, compressed fastq files from sequencing to be
// uncompressed and concatenated into an input file for qcat to
// de-plex.
Channel
    .fromPath("${params.input}/*.fastq.gz", checkIfExists: true)
    .collate(params.batchSize)
    .set { fastq_gz_ch }

// Uncompress and concatenate a batch of Fastq files for qcat to work
// on; qcat takes a single input file and does not read from STDIN.
//
// I've had file corruption errors from qcat when trying to shortcut //
// this step by zcat'ing to qcat and specifying its input file as
// /dev/stdin (perhaps qcat seeks?).
//
// This is safety first, at the expense of disk space.
//
// Channels in:
//   fastq_gz_ch (fastq.gz files)
//
// Channels out:
//   fastq_ch (fastq files)
process gunzip_and_concat {

    memory '500 MB'

    input:
    file chunk from fastq_gz_ch

    output:
    file "uncompressed.fastq" into fastq_ch

    script:
    """
    zcat $chunk > uncompressed.fastq
    """
}

// De-plex the Fastq file with qcat to produce a file per
// barcode. qcat is run with --require-barcodes-both-ends enabled,
// using the --epi2me option. The output files are always named
// "barcode<nn>.fastq", while the unassigned reads are always written
// to a file named "none.fastq". They are written to a nominated
// output directory.
//
// e.g. for an output directory "out":
//
//   ./out/barcode01.fastq
//   ./out/barcode02.fastq
//   ..
//   ./out/none.fastq
//
// qcat has no option to change these names.
//
// Channels in:
//  fastq_ch (fastq files)
//
// Channels out:
//  bc_assigned_ch (barcode assigned fastq files)
//  bc_unassigned_ch (barcode unassigned fastq files)
process deplex_qcat {
    memory '2000 MB'

    input:
    file combined from fastq_ch

    output:
    file("out/barcode*.fastq") into bc_assigned_ch
    file("out/none.fastq") into bc_unassigned_ch

    script:
    """
    qcat --fastq $combined --kit ${params.kit} --epi2me \
      --min-score ${params.minScore} \
      --min-read-length ${params.minReadLength} \
      --require-barcodes-both-ends \
      --barcode_dir out
    """
}

// Gather all the de-plexed files for each barcode index into a
// directory per barcode. Gather the files of unassigned barcodes into
// another directory. Since there are multiple files with the same
// name on the input channel, their names are prefixed with a UUID on
// writing, one UUID per batch of files.
//
// e.g. for an output directory "out":
//
//   ./out/barcode01/<uuid 1>_barcode01.fastq
//   ./out/barcode01/<uuid 2>_barcode01.fastq
//   ./out/barcode02/<uuid 1>_barcode02.fastq
//   ./out/barcode02/<uuid 2>_barcode02.fastq
//   ..
//   ./out/unassigned/<uuid 1>_none.fastq
//   ./out/unassigned/<uuid 2>_none.fastq
//
// Channels in:
//   bc_assigned_ch (barcode assigned fastq files)
//   bc_unassigned_ch (barcode unassigned fastq files)
//   
// Channels out:
//   bc_assigned_out (barcode assigned fastq files)
//   bc_unassigned_out (barcode unassigned fastq files)
process combine {
    publishDir "${params.output}" //, mode: 'copy'

    memory '500 MB'

    input:
    file barcode from bc_assigned_ch
    file unassigned from bc_unassigned_ch

    output:
    file "barcode*/*.fastq" into bc_assigned_out
    file "unassigned/*none.fastq" into bc_unassigned_out

    script:
    """
    uuid=\$(uuidgen -r)
    for b in ${barcode}
    do
        dir=\${b%.fastq}
        mkdir -p \$dir
        mv \${b} \$dir/\${uuid}_\${b}
    done
    
    mkdir -p unassigned
    for u in ${unassigned}
    do
        mv \${u} unassigned/\${uuid}_\${u}
    done
    """
}

bc_assigned_out.subscribe { println it }
bc_unassigned_out.subscribe { println it }
