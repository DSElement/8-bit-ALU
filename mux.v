module mux #(
    parameter WIDTH = 16,     // Data width
    parameter N = 4           // Number of inputs
)(
    input wire [N*WIDTH-1:0] in, // Flattened input bus
    input wire [$clog2(N)-1:0] sel,
    output wire [WIDTH-1:0] out
);

    assign out = in[sel*WIDTH +: WIDTH];

endmodule
