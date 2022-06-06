#!/bin/bash

set -euo pipefail

for build in 5*; do
	TAG=simcop2387/perl:$(echo $build | perl -pE 's/,/-/g')
	LOCAL_TAG=registry.docker.home.simcop2387.info:443/simcop2387/perl:$(echo $build | perl -pE 's/,/-/g')
	PLATFORMS=linux/amd64,linux/arm64
	if [[ $build == *"quadmath"* ]]; then
		# exclude arm64 from quadmath builds since it doesn't apply
		PLATFORMS=linux/amd64
	fi
	echo building $TAG...
        ( cd $build;
        docker buildx build --platform=linux/amd64,linux/arm64 --progress=simple -t $TAG -t $LOCAL_TAG . 2>&1 && \
        docker push $TAG && \
        docker push $LOCAL_TAG
        ) | ts "$TAG [%H:%M:%S]" | tee build.$TAG.log || echo "  Failed to build $TAG"
done

