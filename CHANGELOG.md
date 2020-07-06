# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2020-07-06

### Added

- Add paramters to the wrapper script to set adapter/barcode trimming
  on, the barcode set to be "PBC096andrew" and the Fastq batch size to
  be 50.

### Changed

- Update ncov2019-artic-nf from v0.7.0 to v0.9.0,
  removing the need to patch the nanopore workflow.

- Barcode/adapter trimming from off to on.

- Default Fastq batch size from 10 to 50.

## [0.2.0] - 2020-06-22

### Added

- This change log.

- qcat report, trace and timeline generation.

- Adapter/barcode trimming parameter.

## [0.1.0] - 2020-06-19

### Changed

- Set the primerScheme parameter to V3.

### Added

- Nanopore workflow patch for minReadsPerBarcode parameter.

### Fixed

- Correct the sanity check for the ncov2019-artic-nf directory.
