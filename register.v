module register #(parameter WIDTH = 8) (
    input wire clk,
    input wire [WIDTH-1:0] d,
    output wire [WIDTH-1:0] q
);

    wire [WIDTH-1:0] qn_unused; // <-- dummy wires for unconnected qn

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : gen_dffs
            dff dff_inst (
                .clk(clk),
                .reset(1'b0), // <- add dummy reset low because your dff expects reset
                .d(d[i]),
                .q(q[i]),
                .qn(qn_unused[i])
            );
        end
    endgenerate

endmodule


`timescale 1ns/1ps

module register_tb;

    reg clk;
    reg [7:0] d;
    wire [7:0] q;

    // Instantiate 8-bit register
    register #(8) uut (
        .clk(clk),
        .d(d),
        .q(q)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $display("Time | clk | d       | q");
        $monitor("%4t |  %b  | %b | %b", $time, clk, d, q);

        d = 8'b00000000;
        @(negedge clk); d = 8'b10101010;
        @(negedge clk); d = 8'b01010101;
        @(negedge clk); d = 8'b11110000;
        @(negedge clk); d = 8'b00001111;
        @(negedge clk); d = 8'b11111111;
        @(negedge clk); d = 8'b00000000;
        #20;
        $stop;
    end

endmodule
