module booth (
    input wire clk,
    input wire reset,
    input wire load,      // signal to load multiplicand and multiplier
    input wire shift_en,  // signal to shift
    input wire add_en,    // signal to enable add/sub
    input wire sub_en,    // signal to enable sub
    input wire count_en,  // signal to enable counter
    input wire [7:0] multiplicand,
    input wire [7:0] multiplier,
    output wire [15:0] product,
    output wire done
);

    wire [16:0] reg_data;
    wire [16:0] shifted_data;
    wire [8:0] addsub_result;
    wire [2:0] count;

    // Splitting reg_data into fields
    wire [8:0] A = reg_data[16:9];
    wire [7:0] Q = reg_data[8:1];
    wire Qm1 = reg_data[0];

    // Load multiplicand and multiplier
    wire [16:0] load_value = {9'b0, multiplier, 1'b0};

    // Parallel adder/subtractor
    add_sub #(9) addsub_inst (
        .a(A),
        .b({multiplicand[7], multiplicand}), // sign-extend multiplicand to 9 bits
        .sub(sub_en),                        // sub_en = 1 for subtract, add_en = 1 for add
        .sum(addsub_result)
    );

    // Main working register (A, Q, Q-1)
    wire [16:0] next_reg_data;

    assign next_reg_data = load ? load_value :
                            add_en ? {addsub_result, reg_data[7:0]} :
                            sub_en ? {addsub_result, reg_data[7:0]} :
                            shift_en ? shifted_data :
                            reg_data;

    register #(17) reg_AQ (
        .clk(clk),
        .d(next_reg_data),
        .q(reg_data)
    );

    // Right arithmetic shifter
    shifter #(17) shifter_inst (
        .in(reg_data),
        .out(shifted_data)
    );

    // Counter
    counter #(3) count_inst (
        .clk(clk),
        .reset(reset),
        .enable(count_en),
        .count(count)
    );

    assign done = (count == 3'b111);  // done when 8 cycles completed

    assign product = reg_data[16:1];  // A[8:0] + Q[7:0]

endmodule
