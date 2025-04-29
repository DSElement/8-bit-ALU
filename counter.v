module counter #(parameter WIDTH = 3) (
    input wire clk,
    input wire reset,
    input wire enable,
    output wire [WIDTH-1:0] count
);

    wire [WIDTH-1:0] next_count;
    wire [WIDTH-1:0] selected_d;
    wire [WIDTH-1:0] one;
    wire nreset, nenable;

    // Constant 1
    assign one = {{(WIDTH-1){1'b0}}, 1'b1}; // still OK: constants usually assigned outside synthesis

    // Next count = count + 1
    add_sub #(WIDTH) add_inst (
        .a(count),
        .b(one),
        .sub(1'b0), // always add
        .sum(next_count)
    );

    not (nreset, reset);
    not (nenable, enable);

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : gen_mux
            wire hold_current, load_next, zero_reset;
            and (hold_current, count[i], nreset, nenable);     // when reset=0 and enable=0 ? hold
            and (load_next, next_count[i], nreset, enable);     // when reset=0 and enable=1 ? load next_count
            and (zero_reset, 1'b0, reset);                     // when reset=1 ? load 0 (always zero)
            or (selected_d[i], hold_current, load_next, zero_reset);
        end
    endgenerate

    // Register
    register #(WIDTH) reg_inst (
        .clk(clk),
        .d(selected_d),
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
