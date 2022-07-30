# coreos-assembler

This is a multi-arch build of
[github.com/coreos/coreos-assembler](https://github.com/coreos/coreos-assembler).

The CoreOS developers only provide `x86` images. Building an `arm64`/`aarch64`
image of `coreos-assembler` takes a few hours on a Raspberry Pi 4B, so this is
an attempt to same some time when building custom CoreOS images for ARM.

The workflow's build container is Fedora 36 with Docker to take advantage of
existing Github Actions.

Both `amd64` (`x86_64`) and `arm64` (`aarch64`) images are built here for
convenience.

## Changes

The only change to the image is the `org.opencontainers.image.source` label to
associate the package with the
[`github.com/wranders/lab`](https://github.com/wranders/lab) repository.

## Usage

This image is available from the Github Container Registry (GHCR) and Quay.io:

```sh
docker pull ghcr.io/wranders/coreos-assembler:latest
```

```sh
docker pull quay.io/wranders/coreos-assembler:latest
```

## License

The compiled
[`coreos/coreos-assembler`](https://github.com/coreos/coreos-assembler) is
distributed under the **Apache License 2.0**, which can be found in that
project's repository
**[here](https://github.com/coreos/coreos-assembler/blob/main/LICENSE)**.
