#!/bin/bash

set -euxo pipefail

for build in 5*; do
        TAG=simcop2387/perl:$build
        ( cd $build;
        docker build -t $TAG .
        docker push $TAG
        )
done

