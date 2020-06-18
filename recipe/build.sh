#!/bin/bash

set -euo pipefail

mkdir -p $PREFIX/bin
mkdir -p $PREFIX/share

pushd ncov2019-artic-nf
singularity build --fakeroot artic-ncov2019-nanopore.sif \
            ./environments/nanopore/Singularity
popd

cp $RECIPE_DIR/../bin/qcat-ncov2019-artic-nf.sh $PREFIX/bin
cp -r $RECIPE_DIR/../nextflow -t $PREFIX/share

rm -r ncov2019-artic-nf/.github
cp -r ncov2019-artic-nf -t $PREFIX/share/nextflow
