/*module alu_top (
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

endmodule*/

module alu_top (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [1:0] op_code,
    input wire [7:0] operand_A,
    input wire [7:0] operand_B,
    output wire [15:0] alu_result,
    output wire alu_done
);

    // Internal control wires
    wire adder_en;
    wire subtractor_en;
    wire booth_load, booth_add_en, booth_sub_en, booth_shift_en, booth_count_en;
    wire divider_load, divider_add_en, divider_sub_en, divider_shift_en, divider_count_en, divider_final_add;

    // Datapath wires
    wire [15:0] booth_product;
    wire [7:0] divider_quotient;
    wire [7:0] divider_remainder;
    wire [7:0] add_sub_result;

    wire [15:0] booth_product_bus;
    wire [15:0] add_sub_result_extended;
    wire [15:0] div_concat_result;

    wire [1:0] booth_bits;
    wire booth_counter_done;
    wire divider_sign_R;
    wire divider_counter_done;

    wire [16:0] booth_reg_data;
    wire [15:0] divider_reg_data;

    // MUX flattened input wires
    wire [15:0] option0, option1, option2, option3;
    wire [4*16-1:0] result_options;

    // ========== CONTROL UNIT ==========
    control_unit control_unit_inst (
        .clk(clk),
        .reset(reset),
        .start(start),
        .op_code(op_code),
        .booth_bits(booth_bits),
        .booth_counter_done(booth_counter_done),
        .divider_sign_R(divider_sign_R),
        .divider_counter_done(divider_counter_done),
        .adder_en(adder_en),
        .subtractor_en(subtractor_en),
        .booth_load(booth_load),
        .booth_add_en(booth_add_en),
        .booth_sub_en(booth_sub_en),
        .booth_shift_en(booth_shift_en),
        .booth_count_en(booth_count_en),
        .divider_load(divider_load),
        .divider_add_en(divider_add_en),
        .divider_sub_en(divider_sub_en),
        .divider_shift_en(divider_shift_en),
        .divider_count_en(divider_count_en),
        .divider_final_add(divider_final_add),
        .alu_done(alu_done)
    );

    // ========== Booth Datapath ==========
    booth booth_datapath (
        .clk(clk),
        .reset(reset),
        .load(booth_load),
        .shift_en(booth_shift_en),
        .add_en(booth_add_en),
        .sub_en(booth_sub_en),
        .count_en(booth_count_en),
        .multiplicand(operand_A),
        .multiplier(operand_B),
        .product(booth_product),
        .done(booth_counter_done),
        .reg_data(booth_reg_data)
    );

    // ========== Divider Datapath ==========
    divider divider_datapath (
        .clk(clk),
        .reset(reset),
        .load(divider_load),
        .shift_en(divider_shift_en),
        .add_en(divider_add_en),
        .sub_en(divider_sub_en),
        .final_add(divider_final_add),
        .count_en(divider_count_en),
        .dividend(operand_A),
        .divisor(operand_B),
        .quotient(divider_quotient),
        .remainder(divider_remainder),
        .done(divider_counter_done),
        .reg_data(divider_reg_data)
    );

    // ========== ADD/SUB ==========
    add_sub #(8) add_sub_inst (
        .a(operand_A),
        .b(operand_B),
        .sub(op_code[0]), // sub=0 for ADD, sub=1 for SUB
        .sum(add_sub_result)
    );

    // ===================
    // Structural connections
    // ===================

    // booth_bits from booth_reg_data
    buf (booth_bits[0], booth_reg_data[0]);
    buf (booth_bits[1], booth_reg_data[1]);

    // divider_sign_R from divider_reg_data[15]
    buf (divider_sign_R, divider_reg_data[15]);

    // Expand add_sub_result_extended
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : extend_addsub
            buf (add_sub_result_extended[i], add_sub_result[i]);
            buf (add_sub_result_extended[i+8], 1'b0); // Upper 8 bits zero
        end
    endgenerate

    // Expand div_concat_result
    generate
        for (i = 0; i < 8; i = i + 1) begin : concat_div
            buf (div_concat_result[i+8], divider_remainder[i]); // high byte
            buf (div_concat_result[i], divider_quotient[i]);    // low byte
        end
    endgenerate

    // booth_product bus
    generate
        for (i = 0; i < 16; i = i + 1) begin : booth_prod_copy
            buf (booth_product_bus[i], booth_product[i]);
        end
    endgenerate

    // Create options for the MUX
    generate
        for (i = 0; i < 16; i = i + 1) begin : options_mux
            buf (option0[i], add_sub_result_extended[i]); // ADD/SUB (option 0)
            buf (option1[i], add_sub_result_extended[i]); // ADD/SUB (option 1 again, for SUB)
            buf (option2[i], booth_product_bus[i]);       // MUL (Booth)
            buf (option3[i], div_concat_result[i]);       // DIV
        end
    endgenerate

    // Flatten options into single bus
    assign result_options = {option3, option2, option1, option0};

    // ========== Result MUX ==========
    mux #(
        .WIDTH(16),
        .N(4)
    ) result_mux (
        .in(result_options),
        .sel(op_code),
        .out(alu_result)
    );

endmodule

`timescale 1ns/1ps

module alu_top_tb;

    reg clk, reset, start;
    reg [1:0] op_code;
    reg [7:0] operand_A, operand_B;
    wire [15:0] alu_result;
    wire alu_done;

    // Instantiate ALU
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

    // Clock generation: 10ns clock (period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        // Monitor key signals
        //$monitor("T=%0t | reset=%b start=%b op_code=%b | operand_A=%h operand_B=%h | alu_result=%h | alu_done=%b",
                  //$time, reset, start, op_code, operand_A, operand_B, alu_result, alu_done);

	$monitor("T=%0t | reset=%b start=%b op_code=%b | operand_A=%0d operand_B=%0d | alu_result=%0d | alu_done=%b",
        $time, reset, start, op_code, operand_A, operand_B, alu_result, alu_done);

        // Initial values
        reset = 1;
        start = 0;
        op_code = 2'b00;
        operand_A = 8'h00;
        operand_B = 8'h00;

        // Apply Reset
        #20 reset = 0;

        // ========== Test ADD ==========
        #10 operand_A = 8'd15;
            operand_B = 8'd10;
            op_code = 2'b00; // ADD
            start = 1;
        #10 start = 0;
        wait (alu_done);
        #20;

        // ========== Test SUB ==========
        operand_A = 8'd25;
        operand_B = 8'd10;
        op_code = 2'b01; // SUB
        start = 1;
        #10 start = 0;
        wait (alu_done);
        #20;

        // ========== Test MUL (Booth Multiplication) ==========
        operand_A = 8'd5;
        operand_B = 8'd6;
        op_code = 2'b10; // MUL
        start = 1;
        #10 start = 0;
        wait (alu_done);
        #20;

        // ========== Test DIV (Non-restoring Division) ==========
        operand_A = 8'd40;
        operand_B = 8'd6;
        op_code = 2'b11; // DIV
        start = 1;
        #10 start = 0;
        wait (alu_done);
        #20;

        $display("All tests finished.");
        $stop;
    end

endmodule


