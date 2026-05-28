module TOP (
    input CLK,
    input RESET,
    output [4:0] LEDS,
    input RXD,
    output TXD
);
    // Just pass everything into the real SoC
    SOC my_soc (
        .CLK(CLK),
        .RESET(RESET),
        .LEDS(LEDS),
        .RXD(RXD),
        .TXD(TXD)
     );
     
endmodule
