module add_sub #(parameter WIDTH = 9) (
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    input wire sub,  // 0 = add, 1 = subtract
    output wire [WIDTH-1:0] sum
);

    wire [WIDTH-1:0] b_xor_sub;
    wire carry_in;
    wire [WIDTH:0] carry;  // WIDTH+1 carry chain

    assign carry[0] = sub; // Initial carry is sub (0 for add, 1 for sub)

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : gen_adders
            xor (b_xor_sub[i], b[i], sub); // if sub=1, invert b
	    //assign b_xor_sub[i] = sub ? ~b[i] : b[i];
            full_adder fa (
                .a(a[i]),
                .b(b_xor_sub[i]),
                .cin(carry[i]),
                .s(sum[i]),
                .cout(carry[i+1])
            );
        end
    endgenerate

endmodule

`timescale 1ns/1ps

module add_sub_tb;

    reg [8:0] a, b;
    reg sub;
    wire [8:0] sum;

    add_sub #(9) uut (
        .a(a),
        .b(b),
        .sub(sub),
        .sum(sum)
    );

    initial begin
        $display("Time | sub | a        | b        | sum");
        $monitor("%4t |  %b  | %b | %b | %b | %d", $time, sub, a, b, sum, sum);

        a = 9'b000000001; b = 9'b000000001; sub = 0; // 1 + 1
        #10;
        a = 9'b000000101; b = 9'b000000010; sub = 0; // 5 + 2
        #10;
        a = 8'b00000000; b = 8'b00000011; sub = 1;
        #10;
        $stop;
    end

endmodule
