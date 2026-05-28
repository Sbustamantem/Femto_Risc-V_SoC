/**
 * Module: SOC
 * Description: Top-level integration module for a rudimentary System-on-Chip.
 * It acts as the central interconnect, instantiating the FemtoRV32 CPU, 
 * a Block RAM for instruction/data storage, a memory-mapped LED register, 
 * a full-duplex UART peripheral, and clock/reset conditioning infrastructure.
 */
module SOC (
    input        CLK,   // Master external system clock input.
    input        RESET, // Master external system reset input.
    output [4:0] LEDS,  // 5-bit physical output to drive external hardware LEDs.
    input        RXD,   // Physical UART Receive pin.
    output       TXD    // Physical UART Transmit pin.
);

    // =========================================================================
    // System Clock and Reset Infrastructure
    // =========================================================================
    wire clk, resetn; // Internal conditioned clock and active-low reset signals.
    
    // =========================================================================
    // CPU Memory Bus Signals
    // =========================================================================
    wire [31:0] mem_addr;  // 32-bit address bus from the CPU.
    wire [31:0] mem_wdata; // 32-bit write data bus from the CPU.
    reg  [31:0] mem_rdata; // 32-bit read data bus routed back to the CPU (combinatorial reg).
    wire [3:0]  mem_wmask; // 4-bit byte-enable mask for writes (1 bit per byte).
    wire        mem_rstrb; // Read strobe indicator from the CPU.

    // =========================================================================
    // Bus Control Helper Signals
    // =========================================================================
    // Reduction OR: is_writing evaluates to 1 if any bit in the 4-bit write mask is high.
    wire is_writing = |mem_wmask; 
    // Alias for the read strobe to improve code readability across peripheral instantiations.
    wire is_reading = mem_rstrb;  

    // =========================================================================
    // Core Processor Instantiation
    // =========================================================================
    FemtoRV32 CPU (
        .clk(clk),
        .reset(resetn),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb),
        // Memory accesses in this simplistic SoC are assumed to complete in a single cycle. 
        // Therefore, the CPU's wait-state requests are hardwired to 0 (non-blocking).
        .mem_rbusy(1'b0), 
        .mem_wbusy(1'b0)
    );

    // =========================================================================
    // Address Decoder (Memory Map)
    // =========================================================================
    // The memory map is defined by evaluating bits [17:16] of the 32-bit address.
    // Address Range: 0x0000_0000 to 0x0000_FFFF
    wire sel_ram  = (mem_addr[17:16] == 2'b00); 
    // Address Range: 0x0001_0000 to 0x0001_FFFF
    wire sel_leds = (mem_addr[17:16] == 2'b01); 
    // Address Range: 0x0002_0000 to 0x0002_FFFF
    wire sel_uart = (mem_addr[17:16] == 2'b10); 

    // =========================================================================
    // Main Memory (Block RAM) Instantiation
    // =========================================================================
    wire [31:0] ram_rdata; // Dedicated read-back bus from the BRAM.
    
    bram_hex #(
        .MEM_SIZE(256),               // Allocates 256 32-bit words (1 KB total).
        .HEX_FILE("firmware.hex")     // Initial firmware payload loaded at synthesis.
    ) RAM (
        .clk(clk),
        .mem_addr(mem_addr),
        .mem_rdata(ram_rdata),
        .cs(sel_ram),                 // Activated only when address falls in 0x0000_xxxx.
        .rd(is_reading),             
        .wr(is_writing),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask)         // Enables byte-level write masking (e.g., SB, SH instructions).
    );

    // =========================================================================
    // Memory-Mapped UART Peripheral
    // =========================================================================
    wire [31:0] uart_rdata; // Dedicated read-back bus for the UART peripheral.

    // Instantiates the full-duplex CPU_UART controller. This module acts as a 
    // bus slave, allowing the CPU to send/receive serial data and check status flags.
    CPU_UART #(
        .clk_freq(27000000),    // Configured for Tang Primer 20K master clock (27 MHz).
        .baud(115200)           // Standard baud rate for terminal communication.
    ) UART (
        // System Synchronization
        .clk(clk),
        // The CPU_UART module expects an active-high reset, but the SOC uses an 
        // active-low reset infrastructure ('resetn'). We invert it at the port.
        .rst(!resetn),       
        
        // Memory Bus Interface
        .cs(sel_uart),          // Activated when CPU accesses addresses 0x0002_xxxx.
        // We only pass the lowest 4 bits of the address bus. The peripheral 
        // internally checks bit [2] to distinguish between Data (0x0) and Status (0x4).
        .addr(mem_addr[3:0]),   
        .rd(is_reading),        // Active when the CPU initiates a read cycle.
        .wr(is_writing),        // Active when the CPU initiates a write cycle.
        
        // Data Payload Routing
        .d_in(mem_wdata),       // 32-bit data payload moving from CPU to UART.
        .d_out(uart_rdata),     // 32-bit data payload returning to the CPU bus multiplexer.
        
        // External Physical Pins
        .uart_tx(TXD),          // Routes to the top-level Transmit (TX) pin.
        .uart_rx(RXD)           // Routes from the top-level Receive (RX) pin.
    );

    // =========================================================================
    // Memory-Mapped LED Peripheral
    // =========================================================================
    reg [4:0] led_reg = 0; // Internal state register for the 5 LEDs.
    
    always @(posedge clk) begin
        if (!resetn) 
            led_reg <= 0; // Synchronous active-low reset clears the LEDs.
        else if (sel_leds && is_writing) 
            // Latches the lowest 5 bits of the CPU's write data when addressed.
            led_reg <= mem_wdata[4:0]; 
    end
    
    // Invert the register output before driving the physical pins because the 
    // target hardware (Tang Primer) uses Active-Low LED configurations.
    assign LEDS = ~led_reg; 

    // =========================================================================
    // Master Read Data Multiplexer
    // =========================================================================
    // Combinatorial routing block that drives the CPU's read data bus (mem_rdata).
    // It evaluates the active chip select (sel_*) signals to determine which 
    // peripheral's output should be routed back to the processor.
    always @(*) begin
        if (sel_ram) begin
            // Address Region 0x0000_xxxx: Route main memory (BRAM) data.
            mem_rdata = ram_rdata;
            
        end else if (sel_uart) begin
            // Address Region 0x0002_xxxx: Route UART peripheral data or status flags.
            mem_rdata = uart_rdata;
            
        end else if (sel_leds) begin
            // Address Region 0x0001_xxxx: Read-back the current physical LED state.
            // The internal 5-bit register is zero-extended to cleanly fit the 32-bit CPU bus.
            mem_rdata = {27'b0, led_reg}; 
            
        end else begin
            // Default/Fallback: Unmapped memory addresses return 0x0000_0000.
            // This mandatory catch-all ensures all combinatorial paths are defined,
            // preventing the synthesizer from inferring unintended hardware latches.
            mem_rdata = 32'b0;
        end
    end

    // =========================================================================
    // Clock and Reset Generation
    // =========================================================================
    // Sub-module responsible for taking external raw clock/reset signals
    // and providing stable, debounced, and appropriately polarized internal signals.
    Clockworks CW (
        .CLK(CLK),
        .RESET(RESET),
        .clk(clk),
        .resetn(resetn)
    );

endmodule