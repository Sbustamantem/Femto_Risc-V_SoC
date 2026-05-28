# ==============================================================================
# PROJECT: FPGA Toolchain Setup (Tang Primer 20K)
# DESCRIPTION: CMake build script for Verilog synthesis, place & route, 
#              bitstream generation, and hardware flashing via open-source tools.
# ==============================================================================

cmake_minimum_required(VERSION 3.10)
project(FPGA_Toolchain_Setup)

# ==============================================================================
# 1. ENVIRONMENT VALIDATION
# ==============================================================================

# Restrict execution to Linux-based environments (blocks native Windows/macOS)
if(NOT CMAKE_SYSTEM_NAME STREQUAL "Linux")
    message(FATAL_ERROR 
        "\n============================================================\n"
        " [!] ERROR: Unsupported Operating System\n"
        " This open-source FPGA toolchain requires a Linux environment.\n"
        " Please execute within a Native Linux machine or WSL.\n"
        "============================================================\n"
    )
endif()

# Detect WSL vs Native Linux environments to handle USB passthrough logic
set(ENV_TYPE "Native Linux")
if(EXISTS "/proc/version")
    file(READ "/proc/version" KERNEL_INFO)
    if(KERNEL_INFO MATCHES "Microsoft" OR KERNEL_INFO MATCHES "WSL")
        set(ENV_TYPE "WSL")
    endif()
endif()

message(STATUS "[✓] Environment Verified: Running inside ${ENV_TYPE}.")
message(STATUS "====================================================")
message(STATUS " Starting FPGA Toolchain Verification ")
message(STATUS "====================================================")

# ==============================================================================
# 2. TOOLCHAIN DEPENDENCY RESOLUTION
# ==============================================================================

# Locate Python 3 interpreter (Required for GUI utility scripts)
find_package(Python3 COMPONENTS Interpreter REQUIRED)

# Define local binary path for the Tang Primer OSS CAD toolchain
set(TANG_BIN_PATH "${CMAKE_CURRENT_SOURCE_DIR}/Tools/Tang-primer-20k-oss-cad/bin")

# Locate Yosys (System-wide)
find_program(YOSYS_BIN NAMES yosys)
if(NOT YOSYS_BIN)
    message(SEND_ERROR "\n[!] yosys is missing.\n    -> Fix: Run 'sudo apt update && sudo apt install yosys'\n")
else()
    message(STATUS "[✓] yosys: FOUND at ${YOSYS_BIN}")
endif()

# Locate openFPGALoader (System-wide)
find_program(OPENFPGALOADER_BIN NAMES openFPGALoader)
if(NOT OPENFPGALOADER_BIN)
    message(SEND_ERROR "\n[!] openFPGALoader is missing.\n    -> Fix: Run 'sudo apt install openfpgaloader'\n")
else()
    message(STATUS "[✓] openFPGALoader: FOUND at ${OPENFPGALOADER_BIN}")
endif()

# Locate NextPNR (Prioritize local Tang release binaries)
find_program(NEXTPNR_BIN NAMES nextpnr-himbaechel HINTS ${TANG_BIN_PATH})
if(NOT NEXTPNR_BIN)
    message(SEND_ERROR "\n[!] nextpnr-himbaechel is missing.\n    -> Expected path: ${TANG_BIN_PATH}/nextpnr-himbaechel\n    -> Fix: Download the 'Tang-primer-20k-oss-cad' release and extract it.\n")
else()
    message(STATUS "[✓] nextpnr-himbaechel: FOUND at ${NEXTPNR_BIN}")
endif()

# Locate Gowin Bitstream Packer (Prioritize local Tang release binaries)
find_program(GOWIN_PACK_BIN NAMES gowin_pack HINTS ${TANG_BIN_PATH})
if(NOT GOWIN_PACK_BIN)
    message(SEND_ERROR "\n[!] gowin_pack is missing.\n    -> Expected path: ${TANG_BIN_PATH}/gowin_pack\n    -> Fix: Download the 'Tang-primer-20k-oss-cad' release and extract it.\n")
else()
    message(STATUS "[✓] gowin_pack: FOUND at ${GOWIN_PACK_BIN}")
endif()

message(STATUS "====================================================")

# ==============================================================================
# 3. BUILD PIPELINE (SYNTHESIS -> PNR -> BITSTREAM)
# ==============================================================================

# Collect all hardware description and header files for dependency tracking
file(GLOB SRC_FILES 
    "${CMAKE_CURRENT_SOURCE_DIR}/src/*.v" 
    "${CMAKE_CURRENT_SOURCE_DIR}/src/*.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/*.vh"
)

# Step 1: Synthesis (Verilog -> JSON via Yosys)
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/synth.json
    COMMAND ${YOSYS_BIN} -p "read_verilog -I${CMAKE_CURRENT_SOURCE_DIR}/src ${CMAKE_CURRENT_SOURCE_DIR}/src/*.v" -p "synth_gowin -top TOP -json ${CMAKE_CURRENT_BINARY_DIR}/synth.json" > ${CMAKE_CURRENT_BINARY_DIR}/yosys.log 2>&1
    DEPENDS ${SRC_FILES} 
    COMMENT "Synthesizing Verilog with Yosys... (Check yosys.log for details)"
)

# Step 2: Place & Route (JSON -> PNR JSON via NextPNR)
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/pnr.json
    COMMAND ${NEXTPNR_BIN} --json ${CMAKE_CURRENT_BINARY_DIR}/synth.json --write ${CMAKE_CURRENT_BINARY_DIR}/pnr.json --device GW2A-LV18PG256C8/I7 --vopt family=GW2A-18 --vopt cst=${CMAKE_CURRENT_SOURCE_DIR}/src/tang_primer_20k.cst > ${CMAKE_CURRENT_BINARY_DIR}/nextpnr.log 2>&1
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/synth.json ${CMAKE_CURRENT_SOURCE_DIR}/src/tang_primer_20k.cst
    COMMENT "Running Place and Route with NextPNR... (Check nextpnr.log for details)"
)

# Step 3: Bitstream Generation (PNR JSON -> .fs via Gowin_Pack)
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/bitstream.fs
    COMMAND ${GOWIN_PACK_BIN} -d GW2A-18 -o ${CMAKE_CURRENT_BINARY_DIR}/bitstream.fs ${CMAKE_CURRENT_BINARY_DIR}/pnr.json > ${CMAKE_CURRENT_BINARY_DIR}/gowin_pack.log 2>&1
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/pnr.json
    COMMENT "Packing Bitstream with Gowin_Pack... (Check gowin_pack.log for details)"
)

# Aggregate build target for the complete compilation pipeline
add_custom_target(bitstream ALL DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/bitstream.fs)

# ==============================================================================
# 4. HARDWARE COMMUNICATION & FLASHING TARGETS
# ==============================================================================

# Define Target FPGA USB Hardware ID
set(FPGA_USB_ID "0403:6010" CACHE STRING "USB Hardware ID for the FPGA board")

# Define hardware attachment command (WSL requires explicit usbipd attach)
set(HW_ATTACH_CMD "")
if(ENV_TYPE STREQUAL "WSL")
    set(HW_ATTACH_CMD COMMAND sh -c "usbipd.exe attach --wsl --hardware-id ${FPGA_USB_ID} || true")
endif()

# Construct standard error payload for missing hardware
string(CONCAT BOARD_NOT_FOUND_MSG
    "echo ''"
    " && echo '------------------------------------------------------------'"
    " && echo ' [!] CRITICAL ERROR: FPGA Board Not Found!'"
    " && echo ' openFPGALoader could not detect your Tang Primer.'"
    " && echo ' Please ensure the board is physically plugged into a USB port.'"
    " && echo ' For WSL ensure the USB is attached using: usbipd.exe attach --wsl --hardware-id ${FPGA_USB_ID}.'"
    " && echo '------------------------------------------------------------'"
    " && echo ''"
    " && exit 1"
)

# Define hardware detection gate utilizing the payload above
set(HW_DETECT_GATE COMMAND sh -c "openFPGALoader --detect >/dev/null 2>/dev/null || ( ${BOARD_NOT_FOUND_MSG} )")

# Target: Flash SRAM (Volatile memory, rapid deployment)
add_custom_target(flash
    ${HW_ATTACH_CMD}
    ${HW_DETECT_GATE}
    COMMAND ${OPENFPGALOADER_BIN} -b tangprimer20k ${CMAKE_CURRENT_BINARY_DIR}/bitstream.fs
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/bitstream.fs
    USES_TERMINAL
    COMMENT "Verifying hardware presence and flashing FPGA SRAM..."
    VERBATIM
)

# Target: Flash ROM (Non-volatile memory, persists on reboot)
add_custom_target(flash_rom
    ${HW_ATTACH_CMD}
    ${HW_DETECT_GATE}
    COMMAND ${OPENFPGALOADER_BIN} -b tangprimer20k -f ${CMAKE_CURRENT_BINARY_DIR}/bitstream.fs -r
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/bitstream.fs
    USES_TERMINAL
    COMMENT "Verifying hardware presence and writing to FPGA Flash Memory..."
)

# ==============================================================================
# 5. UTILITY TARGETS: PIN MULTIPLEXER GUI
# ==============================================================================

# Target: Launch Pin Mapper utility to modify an existing constraint file
add_custom_target(map_pins_modify
    COMMAND ${Python3_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/Tools/PIN_MAP_UI.py" 
            "${CMAKE_CURRENT_SOURCE_DIR}/src/tang_primer_20k.cst" 
            "${CMAKE_CURRENT_SOURCE_DIR}/src/tang_primer_20k.cst"
    USES_TERMINAL
    COMMENT "Launching Port Mapper (Modifying existing CST file)..."
)

# Target: Launch Pin Mapper utility to extract ports from Verilog and generate new CST
add_custom_target(map_pins_new
    COMMAND ${Python3_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/Tools/PIN_MAP_UI.py" 
            "${CMAKE_CURRENT_SOURCE_DIR}/src/TOP.v" 
            "${CMAKE_CURRENT_SOURCE_DIR}/src/tang_primer_20k.cst"
    USES_TERMINAL
    COMMENT "Launching Port Mapper (Creating new CST from TOP.v)..."
)