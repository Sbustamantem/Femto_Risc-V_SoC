/**
 * Module: bram_hex
 * Description: A synchronous Block RAM (BRAM) module designed to act as the 
 * main instruction and data memory for the processor. 
 * * Features:
 * - Dynamically sized based on parameter inputs.
 * - Firmware initialization at synthesis via $readmemh.
 * - Byte-addressable read/write support, which is mandatory for RISC-V 
 * to support partial-word memory instructions like LB, SB, LH, and SH.
 */
module bram_hex #(
    parameter MEM_SIZE = 256,                 // Number of 32-bit words (Default: 256 words = 1 KB)
    parameter HEX_FILE = "firmware.hex"       // Path to the hex file containing compiled RISC-V firmware
)(
    // System Clock
    input             clk,

    // Bus Interface
    input      [31:0] mem_addr,  // 32-bit byte address from the CPU
    output reg [31:0] mem_rdata, // 32-bit read data output back to the CPU
    input             cs,        // Chip Select: Active high when the CPU targets this memory region
    input             rd,        // Read Enable: Active high for load instructions
    input             wr,        // Write Enable: Active high for store instructions
    input      [31:0] mem_wdata, // 32-bit data payload from the CPU to be written
    input      [3:0]  mem_wmask  // 4-bit mask indicating which specific bytes to write (1 bit per byte)
);

    // =========================================================================
    // Internal Configuration & Memory Array
    // =========================================================================
    // Automatically calculates the minimum number of bits needed to address 
    // the specified MEM_SIZE. For 256 words, $clog2(256) returns 8 bits.
    // This allows the module to be easily resized without rewriting routing logic.
    localparam ADDR_WIDTH = $clog2(MEM_SIZE);

    // The actual memory matrix. 
    // Format: reg [word_width] ARRAY_NAME [0 : depth];
    // In hardware synthesis, FPGA toolchains will automatically map this 
    // 2D register array into dedicated silicon Block RAM (BRAM) primitives.
    // Add this attribute right before the reg declaration
    (* ram_style = "block" *) reg [31:0] MEM [0:MEM_SIZE-1];
    // =========================================================================
    // Firmware Initialization
    // =========================================================================
    // Loads the compiled machine code into the BRAM.
    // In simulation, this loads the file at time 0.
    // In FPGA synthesis, the toolchain embeds this data directly into the bitstream,
    // so the memory is pre-loaded with the firmware the moment the FPGA boots.
    initial begin
        $readmemh(HEX_FILE, MEM);
    end

    // =========================================================================
    // Address Translation (Byte Address -> Word Index)
    // =========================================================================
    // RISC-V CPUs issue "Byte Addresses" (e.g., 0x0, 0x1, 0x2, 0x3). 
    // However, our memory array is organized as 32-bit (4-byte) "Words".
    // Therefore, addresses 0, 1, 2, and 3 all reside inside Word Index [0].
    // By discarding the bottom 2 bits (mem_addr[1:0]), we effectively divide the 
    // address by 4, converting the CPU's byte address into our array's word index.
    wire [ADDR_WIDTH-1:0] index = mem_addr[ADDR_WIDTH+1:2];

    // =========================================================================
    // Synchronous Memory Operations
    // =========================================================================
    // Standard BRAM must be synchronous. Reads and writes only occur on the clock edge.
    always @(posedge clk) begin
        
        // Only process memory requests if this specific module is selected by the bus
        if (cs) begin
            
            // -----------------------------------------------------------------
            // READ OPERATION
            // -----------------------------------------------------------------
            if (rd) begin
                // Fetch the entire 32-bit word. If the CPU only wants a single byte (LB), 
                // the CPU's internal logic will extract the specific byte it needs.
                mem_rdata <= MEM[index];
            end

            // -----------------------------------------------------------------
            // WRITE OPERATION (Byte-Masked)
            // -----------------------------------------------------------------
            // To support RISC-V Store Byte (SB) and Store Halfword (SH) instructions,
            // we must be able to overwrite partial words without corrupting the rest 
            // of the data at that index. The 4-bit mem_wmask dictates which bytes to update.
            if (wr) begin
                // mem_wmask[0] controls Byte 0 (Bits 7 to 0)
                if (mem_wmask[0]) MEM[index][7:0]   <= mem_wdata[7:0];
                
                // mem_wmask[1] controls Byte 1 (Bits 15 to 8)
                if (mem_wmask[1]) MEM[index][15:8]  <= mem_wdata[15:8];
                
                // mem_wmask[2] controls Byte 2 (Bits 23 to 16)
                if (mem_wmask[2]) MEM[index][23:16] <= mem_wdata[23:16];
                
                // mem_wmask[3] controls Byte 3 (Bits 31 to 24)
                if (mem_wmask[3]) MEM[index][31:24] <= mem_wdata[31:24];
            end
            
        end
    end
    
endmodule