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

### Dependencies

#### Host Environment (User Installed)
Ensure your system meets the operating system requirement, then install the following tools globally:

* **Operating System:** Linux or Windows Subsystem for Linux (WSL).
* **VSCodium / VS Code:** The primary IDE used to interact with the project. You must install these extensions:
    * **Task Buttons (or similar):** Provides the one-click build and flash buttons in the bottom status bar.
    * **WSL Extension (Crucial for Windows users):** Allows VS Code on Windows to talk seamlessly to your WSL Linux terminal.
* **RISC-V GNU Cross-Compiler (`gcc-riscv64-unknown-elf`):** The bare-metal cross-compiler toolchain used to compile high-level software (C, C++, and Assembly) into RISC-V firmware [2].
* **System Tkinter (`python3-tk`):** The standard GUI library backend for Python. *Note: On Linux/WSL, this must be installed globally via your system package manager (`apt`), as it cannot be installed via `pip` [1].*
* **Ninja:** The fast build system used to execute the compilation steps.
* **Yosys:** Handles the Verilog RTL synthesis process.
* **openFPGALoader:** Utility used to flash the generated bitstream to the FPGA hardware.
* **Python 3:** Required to execute the custom pin-mapping User Interface (UI).

#### Project-Specific Tool Suite (Bundled in Releases)
The remaining Gowin-specific backend tools are packaged inside the optimized `Tools/` folder provided in this repository's GitHub Releases page. You do not need to install these globally:

* **nextpnr-himbaechel:** Executes the place-and-route process for the Gowin FPGA architecture.
* **gowin_pack:** Converts the place-and-route routing database into the final `.fs` bitstream file.
* **customTinker:** Internal project dependencies and utilities required by the pin-mapping UI.

### Installing

**1. Prepare Your Environment (Windows Users Only)**
If you are using Windows, you must install the Windows Subsystem for Linux (WSL) to run the toolchain. Follow the official [Microsoft WSL Installation Guide](https://learn.microsoft.com/en-us/windows/wsl/install) before proceeding. You will also need to install the **WSL extension** within VS Code so it can interface with your Linux environment.

**2. Install Global Dependencies**
Open your Linux terminal (or WSL terminal) and run the following command to update your package manager and install Yosys, openFPGALoader, Python 3:
```bash
sudo apt update && sudo apt install cmake ninja-build yosys openfpgaloader python3 python3-tk gcc-riscv64-unknown-elf bsdextrautils  

```

**3. Clone the Repository**
Download the project source code to your local machine and navigate into the directory:

```bash
git clone https://github.com/sbustamantem/Femto_Risc-V_SoC.git
cd Femto_Risc-V_SoC

```

**4. Install the Local Toolchain**
Go to [**Releases**](https://github.com/sbustamantem/Femto_Risc-V_SoC/releases) tab on the GitHub repository page and download the `Tools.tar.gz` file. Extract it directly into the root of your cloned project so your directory structure looks exactly like this:

```text
Femto_Risc-V_SoC/
├── CMakeLists.txt
├── hw/
├── sw/
└── Tools/

```

**5. Launch Your IDE**
Open the project in VSCodium or VS Code. If you are using WSL, ensure you are still inside the project directory in your terminal and run the following command to link the Linux environment to your Windows IDE:

```bash
code .

```

**6. Install Task Buttons Extension**
Once your IDE is open, navigate to the Extensions tab and search for the **Task Buttons** extension (or similar task runner extensions). Install it so the automated build and flash buttons appear in your bottom status bar.

**7. Execute the Workspace Setup**
Once your terminal is open inside VS Code, run the provided shell script to finalize your editor configuration and task buttons:

```bash
bash Tools/.vscode_setup.sh

```

### Executing program

If you have completed the installation and run the setup script, you will see four task buttons located in the bottom-left corner of your IDE's status bar. You can use these to interact with the FPGA:

**1. Flashing the Firmware**
The project is pre-configured to load the compiled assembly logic directly from `src/firmware.hex`. To upload this to the board:
* Ensure your FPGA is securely plugged into your computer via USB.
* Click the **Flash** button (represented by a thunder icon) in the status bar.
* A prompt will appear asking you to select a memory target. Choose either **SRAM** (for fast, volatile testing) or **ROM** (for persistent storage).

**2. Modifying Pin Constraints**
To change how the SoC's internal logic routes to the physical pins on the FPGA board:
* Click the **[pin-mapping-ui]** button (the first button in the status bar).
* The custom UI will launch. From here, you can either modify the existing `.cst` constraint file or generate a brand new one based on the current `top.v` Verilog definition.
* Save your changes in the UI, then run the **Flash** sequence again to apply the new hardware routing.

**3. Verilog Modifications & Debugging**
If you make changes to the core hardware design in the Verilog (`.v`) files, the synthesis tools will automatically track the impact on the FPGA's resources. 
* After building, check the newly generated `yosys.log` (for synthesis results) and `nextpnr.log` (for place-and-route results) to verify how your custom logic affects the chip's physical footprint and timing.

## Running the Example Programs

This repository includes pre-compiled example programs to run on the SoC. 

To load a new example program onto the processor:

1. Navigate to the `src/Examples/` directory.
2. Open  `Examples_raw_code.txt` copy the raw hexadecimal text of choice.
3. Open the `src/firmware.hex` file in the code editor.
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
* **AI Assistance:** Certain boilerplate Verilog peripherals and UI framework drafts were generated with the assistance of AI coding tools before undergoing human review, modification, and integration into the final architecture.




















