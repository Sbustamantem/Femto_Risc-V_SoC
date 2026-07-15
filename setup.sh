#!/bin/bash

# Get the specific custom Tools from the releases and extract it to the current directory
curl -L  https://github.com/Sbustamantem/Femto_Risc-V_SoC/releases/download/v0.2.0-alpha/Tools.tar.xz | tar -xJf - -C .

# Setting up vscode template
mkdir -p .vscode
cp -r Tools/.vscode_template/. .vscode
rm -rf Tools/.vscode_template