# Femto Risc-V SoC

### Version 0.2.0-alpha

## Description

This project provides a hardware-software co-design sandbox engineered specifically for educational instruction in computer architecture and embedded systems. Built upon the open-source, minimalist FemtoRV RISC-V processor core, the environment instantiates a custom System-on-Chip (SoC) topology targetable to FPGA hardware platforms. 

The primary objective is to demystify how abstract high-level C code translates into physical electronic manipulation. By removing the complexities of an operating system or extensive runtime libraries, students interface directly with the bare metal. Programs are compiled to machine code, mapped into a local memory architecture, and executed directly on the RISC-V core. 

Students learn the mechanics of Memory-Mapped I/O (MMIO) by developing custom application logic to drive diverse physical peripherals. To ensure an immediate, deterministic workflow, the repository pairs with an optimized, platform-specific tools release. This eliminates complex global software dependency configurations and isolates the complete toolchain pipeline within the local workspace environment.

## Features

* **Core Architecture**
    * **HLS / Software Compilation:** Compiles high-level languages (such as C or C++) directly into a `.hex` file that can be processed by the Verilog `$readmemh` system task.
    * **Hex Code Execution:** Executes compiled assembly logic directly on the physical RISC-V architecture. Code execution is memory-mapped, with the total program size restricted only by the available onboard Block RAM (BRAM) capacity.

* **Supported Languages**
    * **C / C++:** Fully supports standard `C` and `C++` compilation.

* **Hardware & Peripherals**
    * **Supported Boards:** Tang Primer 20K.
    * **Integrated Peripherals:** 
        * Onboard LEDs
        * UART (Universal Asynchronous Receiver-Transmitter)
        * BRAM (Mainly utilized for code instruction reading)
          
* **Developer Tools**
    * **Unified Hardware & Software Toolchain:** Automates the entire firmware-to-hardware pipeline. Seamlessly manages the RISC-V GCC cross-compiler for firmware compilation alongside local, self-contained hardware synthesis tools (nextpnr-himbaechel and gowin_pack) to prevent environment conflicts.
    * **One-Click IDE Integration:** Custom VSCode task buttons to execute the full-stack workflow—compiling HLS firmware, synthesizing Verilog, and flashing SRAM/ROM in one click.
    * **Interactive Pin-Mapping UI:** A custom-built graphical interface to easily map internal SoC logic to physical FPGA pins without manually writing `.cst` files.

## Getting Started

### Installing

VS Code (or VSCodium) is required as the primary IDE regardless of the chosen installation method.

Select the preferred environment below to view specific setup instructions:

[Linux Local OS](#linux-local-os)

[Windows (WLS)](#windows-wls)

[Docker (Any)](#docker)

### Dependencies

#### Host Environment 

* **VS Code:** The primary IDE used to interact with the project. These extensions must be installed:
    * **Task Buttons (or similar):** Provides the one-click build and flash buttons in the bottom status bar.
* **RISC-V GNU Cross-Compiler (`gcc-riscv64-unknown-elf`):** The bare-metal cross-compiler toolchain used to compile high-level software (C, C++, and Assembly) into RISC-V firmware [2].
* **System Tkinter (`python3-tk`):** The standard GUI library backend for Python. 
* **Ninja:** The fast build system used to execute the compilation steps.
* **Yosys:** Handles the Verilog RTL synthesis process.
* **openFPGALoader:** Utility used to flash the generated bitstream to the FPGA hardware.
* **Python 3:** Required to execute the custom pin-mapping User Interface (UI).

#### Project-Specific Tool Suite (Bundled in Releases)
The remaining Gowin-specific backend tools are packaged inside the optimized `Tools/` folder provided in this repository's GitHub Releases page. There is no need to install these globally:

* **nextpnr-himbaechel:** Executes the place-and-route process for the Gowin FPGA architecture.
* **gowin_pack:** Converts the place-and-route routing database into the final `.fs` bitstream file.
* **customTinker:** Internal project dependencies and utilities required by the pin-mapping UI.
---
#### Linux Local OS
**System Requirement:** The automated setup script utilizes the **`apt`** package manager and is designed for Debian-derived Linux distributions.

**Execute Workspace Setup:** Run the automated setup script from the root of the repository directory:
```bash
bash setup.sh
```
---   
#### Windows WLS

1. **IDE Configuration:** Ensure the official **WSL extension** (`ms-vscode-remote.remote-wsl`) is installed in VS Code.
2. **Configure USB Forwarding (`usbipd-win`):** Install `usbipd-win` on the Windows host machine to enable USB device pass-through into the WSL2 kernel. Run the following command in an Administrator Command Prompt or PowerShell:
   ```powershell
   winget install -e --id dorssel.usbipd-win
   ```
3. **Bind and Attach USB Hardware:** Connect the FPGA board via USB, inspect connected devices, and forward the board's bus ID to WSL:
   ```powershell
   usbipd list
   usbipd attach --wsl --busid <BUS_ID>
   ```
4. **Execute Workspace Setup:** Open the repository folder inside the WSL environment in VS Code and execute the setup script:
   ```bash
   bash setup.sh
   ```
---
#### Docker 

1. **IDE Configuration:** The **Dev Containers extension** (`ms-vscode-remote.remote-containers`) must be installed in VS Code across all operating systems.
2. **Host Engine & Permission Requirements:**
   * **Linux Hosts:** Native Docker Engine (**`docker.io`**) is required. Add the active user account to the `docker` user group to grant the container access to USB hardware for flashing:
     ```bash
     sudo apt update && sudo apt install -y docker.io
     sudo usermod -aG docker $USER
     newgrp docker
     ```
   * **Windows Hosts:** **Docker Desktop for Windows** is required, along with `usbipd-win` installed on the Windows host to bind physical USB ports into the container environment (`usbipd attach --wsl --busid <BUS_ID>`).
3. **Launch Container Environment:** Open the repository folder in VS Code, open the Command Palette (`Ctrl+Shift+P`), and select **`Dev Containers: Reopen in Container`**. All compiler packages, toolchain dependencies, and GUI assets will configure automatically inside the container.
---
### Program Execution

Upon completing the workspace installation, four task buttons become available in the bottom status bar of VS Code (or VSCodium) to manage the FPGA hardware and firmware lifecycle:

**1. Workspace Initialization (Required First Step)**
Before executing any build, compilation, or flashing tasks, the build system must be configured:
* Select the **Setup CMake** status bar button (`$(gear)` icon, second button).
* This task prepares the Ninja build engine, validates system paths, and registers cross-compilation dependencies.

**2. Pin Constraints Configuration**
To adjust how internal SoC logic signals map to physical pins on the Tang Primer 20K FPGA:
* Select the **Pin Mapper** status bar button (`| Tang $(circuit-board)` icon, first button).
* Within the graphical interface, choose whether to modify an existing `.cst` constraint file or parse `TOP.v` to generate a new constraint file.
* Save the updated configuration to ensure the new physical pin assignments are applied during bitstream generation.

**3. Software Compilation & Bitstream Synthesis (Required Before Flashing)**
Before uploading logic to physical hardware, the software firmware and hardware design must be compiled:
* Select the **Build** status bar button (`$(tools)` icon, third button).
* **Flexible Execution Workflow:** Software compilation (compiling C or assembly source files into `firmware.hex`) and hardware synthesis (compiling Verilog into the `.fs` bitstream file) can be performed **either together in a single step or separately as individual build targets**, depending on whether software or hardware changes were made.
* Following the build process, consult `yosys.log` (synthesis results) and `nextpnr.log` (place-and-route analysis) inside the `build/` directory to review Block RAM utilization, physical footprint, and timing performance.

**4. Board Flashing**
Once the firmware and bitstream binaries have been built successfully:
* Ensure the FPGA board is connected to the host system via USB.
* Select the **Flash** status bar button (`$(zap) |` lightning icon, fourth button).
* When prompted by the menu, select the target memory destination:
  * **SRAM:** Fast, volatile execution (ideal for rapid testing; cleared upon power loss).
  * **ROM:** Non-volatile, persistent onboard flash storage.

## Running the Example Programs

This repository includes pre-compiled example programs to run on the SoC. 

To load a new example program onto the processor:

1. Navigate to the `sw/Examples/` directory.
2. Open  `Examples_raw_code.txt` copy the raw hexadecimal text of choice.
3. Open the `build/firmware.hex` file in the code editor.
4. Delete the current contents of the file, paste the copied hex code, and save.
5. Rebuild the project to execute the new firmware

## Authors

**[Santiago Bustamante]** * Lead Developer   
* [GitHub Profile](https://github.com/sbustamantem)  

## Roadmap (Future Features)

Here are the planned upgrades and hardware peripheral expansions for future releases:

* **General Purpose I/O & Timers**
    * [ ] GPIO expansion
    * [ ] Hardware Timers
    * [ ] SysTick interruptions
* **Communication Protocols**
    * [ ] I2C Support
    * [ ] SPI Support
* **Advanced Interfaces**
    * [ ] ADC (Analog-to-Digital Converter) integration
    * [ ] SD Card reader integration
    * [ ] Ethernet support

## Version History

* 0.1.0-alpha
    * Initial Release
* 0.2.0-alpha
    * Added HLS Compiling support  

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

This project was made possible thanks to the incredible work of the open-source hardware and software communities:

* **[Bruno Levy (FemtoRV)](https://github.com/BrunoLevy/learn-fpga):** For the excellent BSD-licensed FemtoRV RISC-V core design that serves as the processing foundation for this SoC architecture.
* **[Debian & Ubuntu Packaging Teams](https://tracker.debian.org/pkg/gcc-riscv64-unknown-elf):** For maintaining the pre-compiled `gcc-riscv64-unknown-elf` toolchain, enabling seamless, single-command installation of the bare-metal RISC-V cross-compiler.
* **[Debian BSD Utilities Project](https://tracker.debian.org/pkg/bsdextrautils):** For maintaining the `bsdextrautils` package, which brings standard, lightweight BSD-derived utilities like `hexdump` natively to Linux environments.
* **[YosysHQ & OSS-CAD-Suite](https://github.com/YosysHQ/oss-cad-suite-build):** For providing the robust, open-source synthesis and place-and-route tools (Yosys, nextpnr) bundled in our portable toolchain.
* **[Project Apicula](https://github.com/YosysHQ/apicula):** For the essential Gowin FPGA bitstream documentation and `gowin_pack` utilities.
* **[openFPGALoader](https://github.com/trabucayre/openFPGALoader):** For the universal utility that makes flashing FPGAs seamless.
* **[Tom Schimansky (CustomTkinter)](https://github.com/TomSchimansky/CustomTkinter):** For the modern Python UI library used to build the interactive pin-mapping tool.
* **[Docker & Development Containers](https://containers.dev/):** For providing the containerization platform and specification that enables an isolated, reproducible, and cross-platform one-click development workspace.
* **AI Assistance:** Certain boilerplate Verilog peripherals and UI framework drafts were generated with the assistance of AI coding tools before undergoing human review, modification, and integration into the final architecture.




















