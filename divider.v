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
    output wire done,
    output wire [15:0] reg_data // <-- NEW output
);

    wire [15:0] internal_reg_data;
    wire [15:0] shifted_data;
    wire [7:0] addsub_result;
    wire [2:0] count;
    wire [7:0] R, Q;
    //wire sign_R;
    wire [15:0] final_corrected_data;

    wire sign_rem;
    assign sign_rem = internal_reg_data[15]; // MSB of R (R[7])


    // Split reg_data
    assign R = internal_reg_data[15:8];
    assign Q = internal_reg_data[7:0];
    //assign sign_R = internal_reg_data[16];

    // Load value (R = 0, Q = dividend)
    wire [15:0] load_value = {8'b0, dividend};

    // Parallel adder/subtractor
    add_sub #(8) addsub_inst (
        .a(R),
        .b(divisor),
        .sub(sub_en),
        .sum(addsub_result)
    );

    // Final correction adder (R + Divisor if final correction needed)
    add_sub #(8) final_addsub_inst (
        .a(R),
        .b(divisor),
        .sub(1'b0),
        .sum(final_corrected_data[15:8])
    );

    // Assign lower bits unchanged for final correction
    assign final_corrected_data[7:0] = internal_reg_data[7:0];

    // Unified shifter for left shift
    shifter #(16) shifter_inst (
        .in(internal_reg_data),
        .direction(1'b1),
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
    wire [15:0] next_reg_data;
    assign next_reg_data = reset ? 16'b0 :
			   load        ? load_value :
                           (add_en | sub_en) ? {addsub_result, internal_reg_data[7:1], ~addsub_result[7]} :
                           shift_en    ? shifted_data :
                           (final_add && sign_rem)   ? final_corrected_data :
                           internal_reg_data;

    register #(16) reg_RQ (
        .clk(clk),
        .d(next_reg_data),
        .q(internal_reg_data)
    );

    assign quotient = Q;
    assign remainder = R;
    assign done = (count == 3'b111);

    assign reg_data = internal_reg_data; // <-- expose reg_data outside

endmodule

/*`timescale 1ns/1ps

module divider_tb;

    reg clk;
    reg reset;
    reg load;
    reg shift_en;
    reg add_en;
    reg sub_en;
    reg final_add;
    reg count_en;
    reg [7:0] dividend;
    reg [7:0] divisor;
    wire [7:0] quotient;
    wire [7:0] remainder;
    wire done;
    wire [15:0] reg_data;

    divider DUT (
        .clk(clk),
        .reset(reset),
        .load(load),
        .shift_en(shift_en),
        .add_en(add_en),
        .sub_en(sub_en),
        .final_add(final_add),
        .count_en(count_en),
        .dividend(dividend),
        .divisor(divisor),
        .quotient(quotient),
        .remainder(remainder),
        .done(done),
        .reg_data(reg_data)
    );

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns clock
    end

    initial begin
        $display("Time | Dividend | Divisor | Quotient | Remainder | reg_data | done");
        $monitor("%4t | %d | %d | %d | %d | %b | %b",
            $time, dividend, divisor, quotient, remainder, reg_data, done);

        // Reset
        reset = 1; load = 0; shift_en = 0; add_en = 0; sub_en = 0; final_add = 0; count_en = 0;
        dividend = 0; divisor = 0;
        #20;
        reset = 0;

        // ==============
        // Test: 20 / 3
        // ==============
        dividend = 8'b11001001;
        divisor = 8'd5;

        // Load
        load = 1;
        #10;
        load = 0;

        // Perform division steps manually
        repeat (8) begin
            // Shift
            shift_en = 1;
            count_en = 1;
            #10;
            shift_en = 0;
            count_en = 0;

            // Add/Sub based on remainder sign
            if (reg_data[15] == 1'b0) begin
                sub_en = 1;
                #10;
                sub_en = 0;
            end else begin
                add_en = 1;
                #10;
                add_en = 0;
            end
        end

        // Final correction if needed
        if (reg_data[15] == 1'b1) begin
            final_add = 1;
            #10;
            final_add = 0;
        end

        // Wait a bit
        #50;
        $stop;
    end

endmodule*/


