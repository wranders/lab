#!/bin/bash

install_yq() {
    VERSION=$1
    ARCH=$2
    ROOT=${3:-/}
    BASEURL="https://github.com/mikefarah/yq/releases/download/v${VERSION}"
    ARCHIVE="${BASEURL}/yq_linux_${ARCH}.tar.gz"
    echo $ARCHIVE
    curl -# -LO $ARCHIVE
    SUM_ORDER="${BASEURL}/checksums_hashes_order"
    echo $SUM_ORDER
    SUM_LINE=$(curl -# -L $SUM_ORDER | \
        grep -n 'SHA-512' | \
        cut -d':' -f1)
    SUM="${BASEURL}/checksums"
    echo $SUM
    curl -# -L $SUM | \
        grep "yq_linux_${ARCH}.tar.gz" | \
        sed 's/  /\t/g' | \
        cut -f$(($SUM_LINE + 1)) | \
        sed "s/$/ yq_linux_${ARCH}.tar.gz/" | \
        sha512sum --check --status
    SUMSTATUS=$?
    if [ $SUMSTATUS -ne 0 ]; then
        echo "Checksum wrong; exiting"
        exit $SUMSTATUS
    fi
    tar -zxvf "yq_linux_${ARCH}.tar.gz" -C "${ROOT}/usr/local/bin" \
        --extract "./yq_linux_${ARCH}" --transform="s/yq_linux_${ARCH}/yq/"
    rm "yq_linux_${ARCH}.tar.gz"
    "${ROOT}/usr/local/bin/yq" shell-completion bash >> "${ROOT}/etc/bash_completion.d/yq.sh"
}

install_cosign() {
    VERSION=$1
    ARCH=$2
    ROOT=${3:-/}
    BASEURL="https://github.com/sigstore/cosign/releases/download/v${VERSION}"
    ARCHIVE="${BASEURL}/cosign-linux-${ARCH}"
    echo $ARCHIVE
    curl -# -LO $ARCHIVE
    SUM="${BASEURL}/cosign_checksums.txt"
    echo $SUM
    curl -# -L $SUM | \
        sha256sum --check --ignore-missing --status
    SUMSTATUS=$?
    if [ $SUMSTATUS -ne 0 ]; then
        echo "Checksum wrong; exiting"
        exit $SUMSTATUS
    fi
    mv "cosign-linux-${ARCH}" "${ROOT}/usr/local/bin/cosign"
    chmod +x "${ROOT}/usr/local/bin/cosign"
    "${ROOT}/usr/local/bin/cosign" completion bash >> "${ROOT}/etc/bash_completion.d/cosign.sh"
}

install_stepcli() {
    VERSION=$1
    ARCH=$2
    ROOT=${3:-/}
    BASEURL="https://github.com/smallstep/cli/releases/download/v${VERSION}"
    ARCHIVE="${BASEURL}/step_linux_${VERSION}_${ARCH}.tar.gz"
    echo $ARCHIVE
    curl -# -LO $ARCHIVE
    SIG="${BASEURL}/step_linux_${VERSION}_${ARCH}.tar.gz.sig"
    echo $SIG
    curl -# -LO $SIG
    CERT="${BASEURL}/step_linux_${VERSION}_${ARCH}.tar.gz.pem"
    echo $CERT
    curl -# -LO $CERT
    COSIGN_EXPERIMENTAL=1 "${ROOT}/usr/local/bin/cosign" verify-blob \
        --certificate "step_linux_${VERSION}_${ARCH}.tar.gz.pem" \
        --signature "step_linux_${VERSION}_${ARCH}.tar.gz.sig" \
        "step_linux_${VERSION}_${ARCH}.tar.gz"
    SUMSTATUS=$?
    if [ $SUMSTATUS -ne 0 ]; then
        echo "Cosign signature wrong; exiting"
        exit $SUMSTATUS
    fi
    tar -zxvf "step_linux_${VERSION}_${ARCH}.tar.gz" \
        -C "${ROOT}/usr/local/bin" --strip-components=2 \
        --extract "step_${VERSION}/bin/step"
    "${ROOT}/usr/local/bin/step" completion bash >> "${ROOT}/etc/bash_completion.d/stepcli.sh"
    rm "step_linux_${VERSION}_${ARCH}.tar.gz" "step_linux_${VERSION}_${ARCH}.tar.gz.sig"
}

install_helm() {
    VERSION=$1
    ARCH=$2
    ROOT=${3:-/}
    BASEURL="https://get.helm.sh"
    ARCHIVE="${BASEURL}/helm-v${VERSION}-linux-${ARCH}.tar.gz"
    echo $ARCHIVE
    curl -# -LO $ARCHIVE
    SUM="${BASEURL}/helm-v${VERSION}-linux-${ARCH}.tar.gz.sha256sum"
    echo $SUM
    curl -# -L $SUM | \
        sha256sum --check --status
    SUMSTATUS=$?
    if [ $SUMSTATUS -ne 0 ]; then
        echo "Checksum wrong; exiting"
        exit $SUMSTATUS
    fi
    tar -zxvf "helm-v${VERSION}-linux-${ARCH}.tar.gz" \
        -C "${ROOT}/usr/local/bin" --strip-components=1 linux-${ARCH}/helm
    "${ROOT}/usr/local/bin/helm" completion bash >> "${ROOT}/etc/bash_completion.d/helm.sh"
    rm "helm-v${VERSION}-linux-${ARCH}.tar.gz"
}

FUNC=${1}
shift
$FUNC "$@"