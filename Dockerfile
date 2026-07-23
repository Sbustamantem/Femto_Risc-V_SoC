#OS
FROM debian:trixie
 
ENV DEBIAN_FRONTEND=noninteractive

#Dependencies
RUN apt update && apt install -y \
    cmake \
    ninja-build \
    yosys \
    openfpgaloader \
    python3 \
    python3-tk \
    gcc-riscv64-unknown-elf \
    bsdextrautils \
    curl \
    xz-utils \
    libgl1 \
    libmd4c0 \
    libdouble-conversion3 \
    libpcre2-16-0 \
    && rm -rf /var/lib/apt/lists/*  

#Working directory
WORKDIR /workspace



