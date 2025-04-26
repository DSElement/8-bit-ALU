module counter #(parameter WIDTH = 3) ( // 3 bits for Booth
    input wire clk,
    input wire reset,
    input wire enable,
    output wire [WIDTH-1:0] count
);

    wire [WIDTH-1:0] next_count;
    wire [WIDTH-1:0] one;

    assign one = {{(WIDTH-1){1'b0}}, 1'b1}; // constant 1

    add_sub #(WIDTH) add_inst (
        .a(count),
        .b(one),
        .sub(1'b0),  // always add 1
        .sum(next_count)
    );

    register #(WIDTH) reg_inst (
        .clk(clk),
        .d(reset ? {WIDTH{1'b0}} : (enable ? next_count : count)),
        .q(count)
    );

endmodule

`timescale 1ns/1ps

module counter_tb;

    reg clk;
    reg reset;
    reg enable;
    wire [2:0] count;

    counter #(3) uut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .count(count)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns clock period
    end

    initial begin
        $display("Time | clk reset enable | count");
        $monitor("%4t |  %b    %b     %b    | %b", $time, clk, reset, enable, count);

        reset = 1;
        enable = 0;
        #10;
        reset = 0;
        enable = 1;
        #100;
        enable = 0;
        #20;
        enable = 1;
        #50;
        $stop;
    end

endmodule
