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

    wire [7:0] quot_view, rem_view;
    assign rem_view = alu_result[15:8];
    assign quot_view = alu_result[7:0];

    // Clock generation: 10ns clock period
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset = 1;
        start = 0;
        op_code = 2'b00;
        operand_A = 8'h00;
        operand_B = 8'h00;

        #20 reset = 0;

        // ===== ADD =====
        #10 operand_A = 8'd16;
            operand_B = 8'd77;
            op_code = 2'b00;
            start = 1;
        #10 start = 0;
        wait (alu_done);
        $display("ADD Done: %0d + %0d = %0d", operand_A, operand_B, alu_result);
        #20;

        // ===== SUB =====
        operand_A = 8'd41;
        operand_B = 8'd22;
        op_code = 2'b01;
        start = 1;
        #10 start = 0;
        wait (alu_done);
        $display("SUB Done: %0d - %0d = %0d", operand_A, operand_B, alu_result);
        #20;

        // ===== MUL =====
        operand_A = 8'd113;
        operand_B = 8'd13;
        op_code = 2'b10;
        start = 1;
        #10 start = 0;
        wait (alu_done);
        $display("MUL Done: %0d * %0d = %0d", operand_A, operand_B, alu_result);
        #20;

        // ===== DIV =====
        operand_A = 8'd244;
        operand_B = 8'd27;
        op_code = 2'b11;
        start = 1;
        #10 start = 0;
        wait (alu_done);
        $display("DIV Done: %0d / %0d = Quotient: %0d  Remainder: %0d",
                  operand_A, operand_B, quot_view, rem_view);
        #20;

        $display("All tests finished.");
        $stop;
    end

endmodule



