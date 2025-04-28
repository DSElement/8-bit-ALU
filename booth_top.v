module booth_top (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [7:0] multiplicand,
    input wire [7:0] multiplier,
    output wire [15:0] product,
    output wire booth_done
);

    // Internal signals
    wire load, shift_en, add_en, sub_en, count_en;
    wire done;
    wire [16:0] reg_data;

    // Instantiate booth datapath
    booth booth_inst (
        .clk(clk),
        .reset(reset),
        .load(load),
        .shift_en(shift_en),
        .add_en(add_en),
        .sub_en(sub_en),
        .count_en(count_en),
        .multiplicand(multiplicand),
        .multiplier(multiplier),
        .product(product),
        .done(done),
        .reg_data(reg_data) // for FSM to see booth_bits
    );

    // Instantiate booth FSM controller
    booth_fsm fsm_inst (
        .clk(clk),
        .reset(reset),
        .start(start),
        .booth_bits(reg_data[1:0]), // Q0 and Q-1 bits
        .done(done),
        .load(load),
        .shift_en(shift_en),
        .add_en(add_en),
        .sub_en(sub_en),
        .count_en(count_en),
        .booth_done(booth_done)
    );

endmodule

`timescale 1ns / 1ps

module booth_top_tb;

    // Inputs
    reg clk;
    reg reset;
    reg start;
    reg [7:0] multiplicand;
    reg [7:0] multiplier;

    // Outputs
    wire [15:0] product;
    wire booth_done;

    // Instantiate booth_top
    booth_top uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .multiplicand(multiplicand),
        .multiplier(multiplier),
        .product(product),
        .booth_done(booth_done)
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
        multiplicand = 8'b0;
        multiplier = 8'b0;

        #20;
        reset = 0;

        // Set multiplicand and multiplier
        multiplicand = 8'd20;   // 5
        multiplier   = 8'd16;   // × 3

        // Start Booth multiplication
        #10;
        start = 1;
        #10;
        start = 0; // one clock pulse

        // Wait until booth_done
        wait (booth_done == 1);

        // Check product
        #20;
        $display("Multiplicand: %d, Multiplier: %d, Product: %d", multiplicand, multiplier, product);

        // Finish simulation
        #20;
        $finish;
    end

endmodule
