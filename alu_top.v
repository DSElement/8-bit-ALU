module alu_top (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [1:0] op_code,         // 00 add, 01 sub, 10 mul, 11 div
    input wire [7:0] operand_A,
    input wire [7:0] operand_B,
    output wire [15:0] alu_result,
    output wire alu_done
);

    // Control signals
    wire load_operands;
    wire adder_en;
    wire subtractor_en;
    wire booth_start;
    wire divider_start;
    wire booth_done;
    wire divider_done;

    // Outputs from Booth and Divider
    wire [15:0] booth_product;
    wire [7:0] divider_quotient;
    wire [7:0] divider_remainder;

    // Adder/Subtractor output
    wire [7:0] add_sub_result;

    // Result options to MUX
    wire [15:0] add_sub_result_extended;
    wire [15:0] div_concat_result;
    //wire [3*16-1:0] result_options; // Flattened bus for 3 options
    wire [4*16-1:0] result_options;


    // Control Unit
    control_unit control_unit_inst (
        .clk(clk),
        .reset(reset),
        .start(start),
        .op_code(op_code),
        .booth_done(booth_done),
        .divider_done(divider_done),
        .adder_en(adder_en),
        .subtractor_en(subtractor_en),
        .booth_start(booth_start),
        .divider_start(divider_start),
        .load_operands(load_operands),
        .alu_done(alu_done)
    );

    // Booth Top (for multiplication)
    booth_top booth_inst (
        .clk(clk),
        .reset(reset),
        .start(booth_start),
        .multiplicand(operand_A),
        .multiplier(operand_B),
        .product(booth_product),
        .booth_done(booth_done)
    );

    // Divider Top (for division)
    divider_top divider_inst (
        .clk(clk),
        .reset(reset),
        .start(divider_start),
        .dividend(operand_A),
        .divisor(operand_B),
        .quotient(divider_quotient),
        .remainder(divider_remainder),
        .divider_done(divider_done)
    );

    // Adder/Subtractor (for ADD and SUB)
    add_sub #(8) add_sub_inst (
        .a(operand_A),
        .b(operand_B),
        //.sub(subtractor_en), // sub=0 for add, sub=1 for subtract
	.sub(op_code[0]), // sub=0 for ADD, sub=1 for SUB
        .sum(add_sub_result)
    );

    // Extend ADD/SUB result to 16 bits (zero extension)
    assign add_sub_result_extended = {8'b0, add_sub_result};

    // Concatenate Quotient and Remainder (for division result)
    assign div_concat_result = {divider_remainder, divider_quotient}; // [15:8] = remainder, [7:0] = quotient

    // Prepare inputs for MUX
    //assign result_options = {booth_product, div_concat_result, add_sub_result_extended};
    assign result_options = {div_concat_result, booth_product, add_sub_result_extended, add_sub_result_extended};


    // MUX: Select correct result based on op_code
    mux #(
        .WIDTH(16),
        .N(4)
    ) result_mux (
        .in(result_options),
        .sel(op_code),
        .out(alu_result)
    );

endmodule

`timescale 1ns / 1ps

module alu_top_tb;

    // Inputs
    reg clk;
    reg reset;
    reg start;
    reg [1:0] op_code;
    reg [7:0] operand_A;
    reg [7:0] operand_B;

    // Outputs
    wire [15:0] alu_result;
    wire alu_done;

    // Instantiate alu_top
    alu_top uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .op_code(op_code),
        .operand_A(operand_A),
        .operand_B(operand_B),
        .alu_result(alu_result),
        .alu_done(alu_done)
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
        op_code = 2'b00;
        operand_A = 0;
        operand_B = 0;

        #20;
        reset = 0;

        // ======== Test ADD (00) ========
        #10;
        operand_A = 8'd20;
        operand_B = 8'd15;
        op_code = 2'b00; // ADD
        start = 1;
        #10;
        start = 0;

        // Wait until alu_done
        wait (alu_done == 1);
        #20;
        $display("ADD Result: %d", alu_result);

        // ======== Test SUB (01) ========
        #50;
        operand_A = 8'd30;
        operand_B = 8'd10;
        op_code = 2'b01; // SUB
        start = 1;
        #10;
        start = 0;

        wait (alu_done == 1);
        #20;
        $display("SUB Result: %d", alu_result);

        // ======== Test MUL (10) ========
        #50;
        operand_A = 8'd7;
        operand_B = 8'd6;
        op_code = 2'b10; // MUL
        start = 1;
        #10;
        start = 0;

        wait (alu_done == 1);
        #20;
        $display("MUL Result: %d", alu_result);

        // ======== Test DIV (11) ========
        #50;
        operand_A = 8'd200;
        operand_B = 8'd13;
        op_code = 2'b11; // DIV
        start = 1;
        #10;
        start = 0;

        wait (alu_done == 1);
        #20;
        $display("DIV Result (Remainder<<8 | Quotient): 0x%h", alu_result);
        $display("-> Quotient: %d", alu_result[7:0]);
        $display("-> Remainder: %d", alu_result[15:8]);

        // Finish simulation
        #100;
        $finish;
    end

endmodule


