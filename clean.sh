#!/bin/bash
for cid in $(docker ps -aq); do
    docker rm "${cid}"
done

for iid in $(docker images | awk '/^<none>/ {print $3}'); do
    docker rmi "${iid}"
done
