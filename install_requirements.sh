sudo apt update

sudo apt install -y \
    build-essential \
    gcc \
    g++ \
    make \
    binutils \
    bison \
    flex \
    gawk \
    texinfo \
    m4 \
    perl \
    python3 \
    python3-venv \
    git \
    curl \
    wget \
    xz-utils \
    zstd \
    bzip2 \
    gzip \
    patch \
    diffutils \
    file \
    rsync \
    cpio \
    bc \
    libgmp-dev \
    libmpfr-dev \
    libmpc-dev \
    libisl-dev \
    libncurses-dev \
    libssl-dev \
    libelf-dev \
    qemu-system-x86 \
    qemu-utils \
    xorriso \
    grub-common \
    grub-pc-bin \
    grub-efi-amd64-bin \
    dosfstools \
    mtools

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

gcc --version
python3 --version
rustc --version
cargo --version
make --version
qemu-system-x86_64 --versiongcc --version
python3 --version
rustc --version
cargo --version
make --version
qemu-system-x86_64 --version


mkdir -p \
    bootstrap/stage0 \
    bootstrap/stage1 \
    bootstrap/stage2 \
    build \
    tools \
    sources \
    build-output \
    sysroot \
    packages/base \
    packages/system \
    packages/networking \
    packages/desktop \
    kernel/config \
    kernel/patches \
    system/init \
    system/services \
    pkgx/src \
    installer \
    iso/grub \
    repository/metadata \
    repository/signing \
    tests \
    docs/architecture \
    docs/build \
    docs/security

