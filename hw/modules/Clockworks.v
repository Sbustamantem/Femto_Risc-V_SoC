module Clockworks(
    input  CLK,      // Raw 27MHz from Tang Primer (Pin H11)
    input  RESET,    // Physical S0 button (Pin T10)
    output clk,      // System clock to everything else
    output resetn    // Active-Low reset to CPU and RAM
);
    // 1. Pass the clock straight through
    assign clk = CLK;

    // 2. Power-on Reset Counter
    // This waits for 65k cycles before letting the CPU wake up
    reg [15:0] reset_cnt = 0;
    assign resetn = &reset_cnt; // Logic 1 only when all bits are 1

    always @(posedge clk or negedge RESET) begin
        if (!RESET) begin // S0 Button is Active Low
            reset_cnt <= 0;
        end else begin
            if (!resetn) reset_cnt <= reset_cnt + 1'b1;
        end
    end
endmodule