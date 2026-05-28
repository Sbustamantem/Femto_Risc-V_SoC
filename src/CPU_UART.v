/**
 * Module: CPU_UART
 * Description: A memory-mapped Universal Asynchronous Receiver-Transmitter (UART) peripheral.
 * It provides a standard AXI/Wishbone-style bus interface for a CPU to send and receive 
 * serial data. The module contains two independent, parallel Finite State Machines (FSMs) 
 * for Transmit (TX) and Receive (RX), allowing full-duplex communication.
 *
 * Memory Map (Based on addr[2]):
 * - Offset 0x0 (addr[2]==0): 
 * - READ: Returns the 8-bit received data (rx_buffer).
 * - WRITE: Triggers transmission of the lowest 8 bits of d_in.
 * - Offset 0x4 (addr[2]==1):
 * - READ: Returns Status Register -> {30'b0, rx_ready, tx_busy}
 * Bit [0]: tx_busy (1 = Transmitter is active, do not write new data).
 * Bit [1]: rx_ready (1 = New data available to read).
 */
module CPU_UART #(
    parameter clk_freq = 27000000, // Master clock frequency in Hz (Default: 27MHz for Tang Primer)
    parameter baud     = 115200    // Target serial baud rate in bits per second (bps)
)(
    // System signals
    input             clk,      // Master system clock
    input             rst,      // Active-High synchronous reset

    // Memory-Mapped Bus Interface
    input             cs,       // Chip Select: Asserted when the CPU addresses this peripheral
    input      [3:0]  addr,     // Address offset: Differentiates between Data (0x0) and Status (0x4)
    input             rd,       // Read Strobe: Asserts when CPU is reading
    input             wr,       // Write Strobe: Asserts when CPU is writing
    input      [31:0] d_in,     // 32-bit write data bus from the CPU
    output reg [31:0] d_out,    // 32-bit read data bus back to the CPU

    // Physical Interface
    output            uart_tx,  // Physical UART Transmit pin (Target M11)
    input             uart_rx   // Physical UART Receive pin (Target T13)
);

    // =========================================================================
    // Baud Rate Generator (Clock Divider)
    // =========================================================================
    // Calculates the number of master clock cycles required to sustain one UART bit.
    // Example: 27,000,000 / 115,200 = 234 clock cycles per bit.
    localparam BAUD_DIV = clk_freq / baud;

    // =========================================================================
    // TRANSMITTER (TX) - Parallel to Serial Conversion
    // =========================================================================
    reg [3:0]  tx_state = 0;      // TX FSM State Tracker
    reg [31:0] tx_clk_cnt = 0;    // TX cycle counter for baud rate timing
    reg [7:0]  tx_buffer;         // Internal shift register holding the outgoing byte
    reg        tx_pin_reg = 1'b1; // Direct register driving the physical TX pin. 
                                  // (Idle state for UART is logic HIGH)
    
    // Drive the physical wire with the register output.
    assign uart_tx = tx_pin_reg;

    // Status flag: TX is busy anytime the FSM is not in state 0 (Idle).
    wire tx_busy = (tx_state != 0);

    always @(posedge clk) begin
        if (rst) begin
            tx_state <= 0;
            tx_pin_reg <= 1'b1; // Default to idle high
            tx_clk_cnt <= 0;
        end else begin
            case (tx_state)
                // STATE 0: IDLE / WAIT FOR CPU
                // FSM remains here until the CPU executes a Write operation to offset 0x0.
                0: if (cs && wr && addr == 0) begin 
                    tx_buffer  <= d_in[7:0]; // Latch the target byte from the CPU bus
                    tx_pin_reg <= 1'b0;      // Assert START BIT (Pull line LOW)
                    tx_clk_cnt <= 0;         // Reset baud counter
                    tx_state   <= 1;         // Advance FSM
                end
                
                // STATES 1-8: SHIFT DATA BITS
                // Sequentially shifts out bits 0 through 7. UART is LSB-first.
                1,2,3,4,5,6,7,8: begin     
                    if (tx_clk_cnt == BAUD_DIV) begin // Wait for 1 full bit duration
                        tx_pin_reg <= tx_buffer[0];   // Drive current LSB to the physical pin
                        tx_buffer  <= tx_buffer >> 1; // Logical right shift (prepares next bit)
                        tx_clk_cnt <= 0;
                        tx_state   <= tx_state + 1;
                    end else tx_clk_cnt <= tx_clk_cnt + 1;
                end
                
                // STATE 9: STOP BIT
                // Asserts the mandatory stop condition to frame the byte.
                9: begin                   
                    if (tx_clk_cnt == BAUD_DIV) begin
                        tx_pin_reg <= 1'b1; // Assert STOP BIT (Pull line HIGH)
                        tx_clk_cnt <= 0;
                        tx_state   <= 10;
                    end else tx_clk_cnt <= tx_clk_cnt + 1;
                end
                
                // STATE 10: SAFETY MARGIN
                // Holds the stop bit for exactly one bit duration before returning to IDLE.
                // This guarantees the receiver on the other end registers the frame boundary.
                10: begin                  
                    if (tx_clk_cnt == BAUD_DIV) tx_state <= 0;
                    else tx_clk_cnt <= tx_clk_cnt + 1;
                end
            endcase
        end
    end

    // =========================================================================
    // RECEIVER (RX) - Serial to Parallel Conversion
    // =========================================================================
    reg [3:0]  rx_state = 0;   // RX FSM State Tracker
    reg [31:0] rx_clk_cnt = 0; // RX cycle counter for baud rate timing
    reg [7:0]  rx_buffer;      // Internal register building the incoming byte
    reg        rx_ready = 0;   // Status flag: Asserts when a full, valid byte is waiting

    always @(posedge clk) begin
        if (rst) begin
            rx_state <= 0;
            rx_ready <= 0;
        end else begin
            case (rx_state)
                // STATE 0: IDLE / EDGE DETECT
                // Watches the physical pin asynchronously for a HIGH-to-LOW drop (Start bit).
                0: begin 
                    if (uart_rx == 0) begin
                        rx_clk_cnt <= 0;
                        rx_state   <= 1;
                        rx_ready   <= 0; // Clear the ready flag for the new transaction
                    end
                end
                
                // STATE 1: ALIGN TO CENTER OF FIRST DATA BIT
                // To safely sample the line, we wait 1.5 bit durations (Start bit + half of Bit 0).
                // This ensures all subsequent samples occur dead-center in the bit window,
                // minimizing the risk of errors from clock drift or noisy edges.
                1: begin 
                    if (rx_clk_cnt == (BAUD_DIV + BAUD_DIV/2)) begin
                        rx_buffer[0] <= uart_rx; // Sample Bit 0
                        rx_clk_cnt   <= 0;
                        rx_state     <= 2;
                    end else rx_clk_cnt <= rx_clk_cnt + 1;
                end
                
                // STATES 2-8: SAMPLE REMAINING BITS
                // Now aligned to the center window, simply wait exactly 1 bit duration per state.
                2,3,4,5,6,7,8: begin 
                    if (rx_clk_cnt == BAUD_DIV) begin
                        rx_buffer[rx_state-1] <= uart_rx; // Reconstruct the byte
                        rx_clk_cnt <= 0;
                        rx_state   <= rx_state + 1;
                    end else rx_clk_cnt <= rx_clk_cnt + 1;
                end
                
                // STATE 9: STOP BIT VALIDATION
                // Waits for the stop bit time window and flags the system.
                9: begin 
                    if (rx_clk_cnt == BAUD_DIV) begin
                        rx_ready <= 1; // Raise the flag: Tell CPU a full byte is waiting in buffer
                        rx_state <= 0; // Return to hunting for the next Start Bit
                    end else rx_clk_cnt <= rx_clk_cnt + 1;
                end
            endcase
            
            // =================================================================
            // AUTO-CLEAR MECHANISM
            // If the CPU successfully reads from Offset 0x0 during this clock cycle,
            // hardware automatically clears the rx_ready flag.
            // =================================================================
            if (cs && rd && addr == 0) rx_ready <= 0;
        end
    end

    // =========================================================================
    // BUS INTERFACE (Combinatorial Read Multiplexer)
    // =========================================================================
    // Routes internal registers back to the CPU based on the requested address.
    // Address checking relies only on addr[2] to safely differentiate 0x0 from 0x4.
    always @(*) begin
        case (addr[2])
            1'b0: d_out = {24'b0, rx_buffer};            // Offset 0x0: Read data buffer
            1'b1: d_out = {30'b0, rx_ready, tx_busy};    // Offset 0x4: Read status flags
            default: d_out = 32'b0;
        endcase
    end

endmodule