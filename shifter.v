module shifter #(parameter WIDTH = 17) (
    input wire [WIDTH-1:0] in,
    input wire direction,  // 0 for right shift, 1 for left shift
    output wire [WIDTH-1:0] out
);

    wire [WIDTH-1:0] left_shift;
    wire [WIDTH-1:0] right_shift;
    wire n_direction;

    not (n_direction, direction);

    // Manually assign MSB and LSB edge conditions
    assign right_shift[WIDTH-1] = in[WIDTH-1]; // MSB sign-extend
    assign left_shift[0] = 1'b0;                // LSB zero insert

    // Generate for internal bits
    genvar i;
    generate
        for (i = 0; i < WIDTH-1; i = i + 1) begin : right_loop
            assign right_shift[i] = in[i+1];
        end

        for (i = 1; i < WIDTH; i = i + 1) begin : left_loop
            assign left_shift[i] = in[i-1];
        end

        for (i = 0; i < WIDTH; i = i + 1) begin : mux_loop
            wire left_and_dir, right_and_ndir;
            and (left_and_dir, left_shift[i], direction);
            and (right_and_ndir, right_shift[i], n_direction);
            or  (out[i], left_and_dir, right_and_ndir);
        end
    endgenerate

endmodule


/*`timescale 1ns/1ps

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

endmodule*/

