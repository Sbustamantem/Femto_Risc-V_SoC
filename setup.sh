sudo apt update

sudo apt install yosys openfpgaloader git bsdextrautils curl xz-utils libgl1 libmd4c0 libdouble-conversion3 libpcre2-16-0 

curl -L  https://github.com/Sbustamantem/Femto_Risc-V_SoC/releases/download/v0.2.0-alpha/Tools.tar.xz | tar -xJf - -C .

export PATH="$PATH:$(pwd)/Tools/Tang-primer-20k-oss-cad/bin"