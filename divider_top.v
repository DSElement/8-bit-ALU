module divider_top (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [7:0] dividend,
    input wire [7:0] divisor,
    output wire [7:0] quotient,
    output wire [7:0] remainder,
    output wire divider_done
);

    // Internal control wires
    wire load, shift_en, add_en, sub_en, count_en, final_add;
    wire done;
    wire [15:0] reg_data;

    // Instantiate divider datapath
    divider divider_inst (
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
        .reg_data(reg_data) // for FSM to see R
    );

    // Instantiate divider FSM controller
    divider_fsm fsm_inst (
        .clk(clk),
        .reset(reset),
        .start(start),
        .sign_R(reg_data[15]), // R[7] bit is MSB of reg_data[15:8]
        .done(done),
        .load(load),
        .shift_en(shift_en),
        .add_en(add_en),
        .sub_en(sub_en),
        .count_en(count_en),
        .final_add(final_add),
        .divider_done(divider_done)
    );

endmodule


`timescale 1ns / 1ps

module divider_top_tb;

    // Inputs
    reg clk;
    reg reset;
    reg start;
    reg [7:0] dividend;
    reg [7:0] divisor;

    // Outputs
    wire [7:0] quotient;
    wire [7:0] remainder;
    wire divider_done;

    // Instantiate divider_top
    divider_top uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .dividend(dividend),
        .divisor(divisor),
        .quotient(quotient),
        .remainder(remainder),
        .divider_done(divider_done)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns clock
    end

    // Stimulus
    initial begin
        // Initialize
        reset = 1;
        start = 0;
        dividend = 8'b0;
        divisor  = 8'b0;

        #20;
        reset = 0;

        // Set dividend and divisor
        dividend = 8'd200;  // 15
        divisor  = 8'd13;   // ÷3

        // Start division
        #10;
        start = 1;
        #10;
        start = 0; // one clock pulse

        // Wait for divider_done
        wait (divider_done == 1);

        // Print results
        #20;
        $display("Dividend: %d, Divisor: %d, Quotient: %d, Remainder: %d", dividend, divisor, quotient, remainder);

        // Finish simulation
        #20;
        $finish;
    end

endmodule

