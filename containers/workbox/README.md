# workbox

Contains tools used to deploy my Lab environment.

## Run

```sh
lab-workbox() {
  podman run -it --rm --security-opt label=disable --name=lab-workbox   \
    --uidmap=1000:0:1 --uidmap=0:1:1000 --uidmap=1001:1001:64536        \
    -v ${PWD}:/home/workbox                                             \
    ${LWB_CONTAINER_RUNTIME_ARGS}                                       \
    ${LWB_CONTAINER_IMAGE:-ghcr.io/wranders/lab-workbox:latest} "$@"
}
```

Env Var                       | Description
:-                            | :-
`LWB_CONTAINER_RUNTIME_ARGS`  | Additional `podman` arguments
`LWB_CONTAINER_IMAGE`         | Alternate image for `lab-workbox`
