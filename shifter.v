module shifter #(parameter WIDTH = 17) (
    input wire [WIDTH-1:0] in,
    input wire direction,  // 0 for right shift, 1 for left shift
    output wire [WIDTH-1:0] out
);
    // Right arithmetic shift: sign-extend MSB
    wire [WIDTH-1:0] right_shift = {in[WIDTH-1], in[WIDTH-1:1]};
    
    // Left shift: shift in 0 at LSB
    wire [WIDTH-1:0] left_shift = {in[WIDTH-2:0], 1'b0};
    
    // Select output based on direction
    assign out = direction ? left_shift : right_shift;
endmodule

`timescale 1ns/1ps

module shifter_tb;

    reg [16:0] in;
    reg direction;
    wire [16:0] out;

    shifter #(17) uut (
        .in(in),
        .direction(direction),
        .out(out)
    );

    initial begin
        $display("Time | direction | in                 | out");
        $monitor("%4t |    %b      | %b | %b", $time, direction, in, out);

        in = 17'b01111111000000001;  // example positive value
        direction = 0; // right shift
        #10;
        direction = 1; // left shift
        #10;
        
        in = 17'b11111111000000001;  // example negative value
        direction = 0; // right shift
        #10;
        direction = 1; // left shift
        #10;

        $stop;
    end

endmodule

