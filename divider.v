module divider (
    input wire clk,
    input wire reset,
    input wire load,          // load dividend and divisor
    input wire shift_en,      // shift left
    input wire add_en,        // add divisor to remainder
    input wire sub_en,        // subtract divisor from remainder
    input wire final_add,     // correct final remainder if negative
    input wire count_en,      // counter enable
    input wire [7:0] dividend,
    input wire [7:0] divisor,
    output wire [7:0] quotient,
    output wire [7:0] remainder,
    output wire done
);

    wire [16:0] reg_data;
    wire [16:0] shifted_data;
    wire [8:0] addsub_result;
    wire [2:0] count;
    wire [7:0] R, Q;
    wire sign_R;
    wire [16:0] final_corrected_data;

    // Split reg_data
    assign R = reg_data[16:9];
    assign Q = reg_data[8:1];
    assign sign_R = reg_data[16];

    // Load value (R = 0, Q = dividend)
    wire [16:0] load_value = {9'b0, dividend};

    // Parallel adder/subtractor
    add_sub #(9) addsub_inst (
        .a({R[7], R}),             // sign-extend R
        .b({divisor[7], divisor}), // sign-extend divisor
        .sub(sub_en),              // sub_en = 1 for subtraction, add_en = 1 for addition
        .sum(addsub_result)
    );

    // Final correction adder (R + Divisor if final correction needed)
    add_sub #(9) final_addsub_inst (
        .a({R[7], R}),
        .b({divisor[7], divisor}),
        .sub(1'b0), // addition
        .sum(final_corrected_data[16:8])
    );

    // Assign lower bits unchanged for final correction
    assign final_corrected_data[7:0] = reg_data[7:0];

    // Unified shifter for left shift
    shifter #(17) shifter_inst (
        .in(reg_data),
        .direction(1'b1), // shift left
        .out(shifted_data)
    );

    // Counter
    counter #(3) counter_inst (
        .clk(clk),
        .reset(reset),
        .enable(count_en),
        .count(count)
    );

    // Main working register logic
    wire [16:0] next_reg_data;
    assign next_reg_data = load        ? load_value :
                           (add_en | sub_en) ? {addsub_result[7:0], reg_data[8:2], ~addsub_result[8]} :
                           shift_en    ? shifted_data :
                           final_add   ? final_corrected_data :
                           reg_data;

    register #(17) reg_RQ (
        .clk(clk),
        .d(next_reg_data),
        .q(reg_data)
    );

    assign quotient = Q;
    assign remainder = R;
    assign done = (count == 3'b111);

endmodule
