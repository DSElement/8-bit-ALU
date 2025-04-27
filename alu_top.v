module alu_top (
    input wire clk,
    input wire reset,
    input wire begin_op,
    input wire [1:0] opcode,     // 00 = add, 01 = sub, 10 = mul, 11 = div
    input wire [7:0] a,           // Operand A
    input wire [7:0] b,           // Operand B
    output wire [15:0] result,    // Final result (Product, Quotient, Sum/Diff)
    output wire done              // Operation complete signal
);

    // ========================
    // Internal wires
    // ========================
    wire booth_load, booth_shift_en, booth_add_en, booth_sub_en, booth_count_en;
    wire div_load, div_shift_en, div_add_en, div_sub_en, div_final_add, div_count_en;
    wire alu_done;
    wire booth_done, div_done;
    wire [15:0] booth_product;
    wire [7:0] div_quotient, div_remainder;
    wire [15:0] add_sub_result;
    wire [16:0] booth_reg_data, div_reg_data;

    // Booth control signals for add/sub decision
    wire booth_Q0, booth_Qm1;
    assign booth_Q0 = booth_reg_data[1];
    assign booth_Qm1 = booth_reg_data[0];

    // Divider remainder sign
    wire div_R_sign;
    assign div_R_sign = div_reg_data[16]; // MSB of remainder

    // ========================
    // Control Unit
    // ========================
    control_unit CU (
        .clk(clk),
        .reset(reset),
        .begin_op(begin_op),
        .opcode(opcode),
        .booth_done(booth_done),
        .div_done(div_done),
        .booth_Q0(booth_Q0),
        .booth_Qm1(booth_Qm1),
        .div_R_sign(div_R_sign),
        .booth_load(booth_load),
        .booth_shift_en(booth_shift_en),
        .booth_add_en(booth_add_en),
        .booth_sub_en(booth_sub_en),
        .booth_count_en(booth_count_en),
        .div_load(div_load),
        .div_shift_en(div_shift_en),
        .div_add_en(div_add_en),
        .div_sub_en(div_sub_en),
        .div_final_add(div_final_add),
        .div_count_en(div_count_en),
        .alu_done(alu_done)
    );

    // ========================
    // Booth Multiplier
    // ========================
    booth booth_multiplier (
        .clk(clk),
        .reset(reset),
        .load(booth_load),
        .shift_en(booth_shift_en),
        .add_en(booth_add_en),
        .sub_en(booth_sub_en),
        .count_en(booth_count_en),
        .multiplicand(a),
        .multiplier(b),
        .product(booth_product),
        .done(booth_done),
        .reg_data(booth_reg_data)   // Export reg_data for Q0, Q-1 reading
    );

    // ========================
    // Divider
    // ========================
    divider divider_unit (
        .clk(clk),
        .reset(reset),
        .load(div_load),
        .shift_en(div_shift_en),
        .add_en(div_add_en),
        .sub_en(div_sub_en),
        .final_add(div_final_add),
        .count_en(div_count_en),
        .dividend(a),
        .divisor(b),
        .quotient(div_quotient),
        .remainder(div_remainder),
        .done(div_done),
        .reg_data(div_reg_data)   // Export reg_data for sign reading
    );

    // ========================
    // Add/Sub (structural)
    // ========================

    add_sub #(16) adder_subtractor ( // use 16 not 9
        .a({8'b0, a}),
        .b({8'b0, b}),
        .sub(opcode[0]),
        .sum(add_sub_result)
    );


    // ========================
    // Result MUX
    // ========================
    wire [15:0] mux_inputs [3:0];

    assign mux_inputs[0] = add_sub_result;
    assign mux_inputs[1] = booth_product;
    assign mux_inputs[2] = {8'b0, div_quotient};
    assign mux_inputs[3] = 16'b0; // Reserved (could be remainder or 0)

    /*mux #(16, 4) result_mux (
        .in({mux_inputs[3], mux_inputs[2], mux_inputs[1], mux_inputs[0]}),
        .sel(opcode),
        .out(result)
    );*/

    mux #(16, 4) result_mux (
        .in({{8'b0, div_quotient}, booth_product, add_sub_result, add_sub_result}),
        .sel(opcode),
        .out(result)
    );


    //assign done = alu_done;
    assign done = (opcode == 2'b00 || opcode == 2'b01) ? 1'b1 : alu_done;

endmodule

`timescale 1ns/1ps

module alu_top_tb;

    reg clk;
    reg reset;
    reg begin_op;
    reg [1:0] opcode;
    reg [7:0] a, b;
    wire [15:0] result;
    wire done;

    alu_top DUT (
        .clk(clk),
        .reset(reset),
        .begin_op(begin_op),
        .opcode(opcode),
        .a(a),
        .b(b),
        .result(result),
        .done(done)
    );

    // Clock generator
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10 ns clock period
    end

    initial begin
    $display("Time | Opcode | A | B | Result | Done | booth_load booth_shift_en booth_add_en booth_sub_en booth_count_en");
    $monitor("%4t | %b | %d | %d | %d | %b | %b %b %b %b %b",
        $time, opcode, a, b, result, done,
        DUT.booth_multiplier.load,
        DUT.booth_multiplier.shift_en,
        DUT.booth_multiplier.add_en,
        DUT.booth_multiplier.sub_en,
        DUT.booth_multiplier.count_en
    );
end


    // Test sequence
    initial begin
        //$display("Time | Opcode | A | B | Result | Done");
        //$monitor("%4t | %b | %d | %d | %d | %b", $time, opcode, a, b, result, done);

        // Global reset
        reset = 1;
        begin_op = 0;
        a = 0;
        b = 0;
        opcode = 2'b00;
        #20;
        reset = 0;

        // =========================
        // Test 1: ADD (5 + 3 = 8)
        // =========================
        a = 8'd5;
        b = 8'd3;
        opcode = 2'b00; // ADD
	#10
        begin_op = 1;
        #20 begin_op = 0; // Pulse
        wait (done);
        #20;
	reset = 1; #10; reset = 0; #10; // <- Reset between operations

        // =========================
        // Test 2: SUB (10 - 4 = 6)
        // =========================
        a = 8'd10;
        b = 8'd4;
        opcode = 2'b01; // SUB
	#10
        begin_op = 1;
        #20 begin_op = 0;
        wait (done);
        #20;
	reset = 1; #10; reset = 0; #10; // <- Reset between operations

        // =========================
        // Test 3: MUL (7 * 3 = 21)
        // =========================
        a = 8'd7;
        b = 8'd3;
        opcode = 2'b10; // MUL
	#10
        begin_op = 1;
        #20 begin_op = 0;
        wait (done);
        #20;
	reset = 1; #10; reset = 0; #10; // <- Reset between operations

        // =========================
        // Test 4: DIV (20 / 3 = 6 quotient)
        // =========================
        a = 8'd20;
        b = 8'd3;
        opcode = 2'b11; // DIV
	#10
        begin_op = 1;
        #20 begin_op = 0;
        wait (done);
        #20;
	reset = 1; #10; reset = 0; #10; // <- Reset between operations

        // Finish
        $stop;
    end

endmodule

