#!/bin/bash

set -euo pipefail

for build in 5*; do
	TAG=simcop2387/perl:$(echo $build | perl -pE 's/,/-/g')
	echo building $TAG...
        ( cd $build;
        docker build -t $TAG .
        docker push $TAG
        ) | ts "$TAG [%H:%M:%S]" | tee build.$TAG.log || echo "  Failed to build $TAG"
done

