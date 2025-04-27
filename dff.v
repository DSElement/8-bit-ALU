module dff(
    input wire clk,
    input wire reset,
    input wire d,
    output wire q,
    output wire qn
);

    wire nclk;
    wire s, r;
    wire qm, qmn;
    wire qs, qsn;
    wire d_reset;   // Data forced to 0 when reset active

    not (nclk, clk);

    // reset forces d_reset = 0
    assign d_reset = reset ? 1'b0 : d;

    // Master latch (transparent when clk=0)
    nand (s, d_reset, nclk);
    nand (r, ~d_reset, nclk);
    nand (qm, s, qmn);
    nand (qmn, r, qm);

    // Slave latch (transparent when clk=1)
    nand (qs, qm, clk);
    nand (qsn, qmn, clk);
    nand (q, qs, qn);
    nand (qn, qsn, q);

endmodule


/*module dff (
    input wire clk,
    input wire d,
    output reg q,
    output wire qn
);

    assign qn = ~q;

    always @(posedge clk)
        q <= d;

endmodule*/


/*`timescale 1ns/1ps

module dff_tb;

    reg clk;
    reg d;
    wire q, qn;

    dff uut (
        .clk(clk),
        .d(d),
        .q(q),
        .qn(qn)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $display("Time | clk d | q qn");
        $monitor("%4t |  %b   %b | %b %b", $time, clk, d, q, qn);

        d = 0;
        @(negedge clk); d = 1;
        @(negedge clk); d = 0;
        @(negedge clk); d = 0;
        @(negedge clk); d = 0;
        @(negedge clk); d = 1;
        @(negedge clk); d = 1;
        @(negedge clk); d = 0;
        @(negedge clk); d = 1;
        #20;
        $stop;
    end

endmodule*/


