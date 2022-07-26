# workbox

Contains tools used to deploy my Lab environment. Includes:

- helm
- jq
- yq
- step

## Run

```sh
podman run -it --rm --security-opt label=disable --name=lab-workbox\
    --uidmap=1000:0:1 --uidmap=0:1:1000 --uidmap=1001:1001:64536 \
    -v ${PWD}:/srv/ ghcr.io/wranders/lab-workbox:latest;
```

```sh
alias lab-workbox="podman run -it --rm --security-opt label=disable --name=lab-workbox --uidmap=1000:0:1 --uidmap=0:1:1000 --uidmap=1001:1001:64536 -v ${PWD}:/srv/ ghcr.io/wranders/lab-workbox:latest"
```
