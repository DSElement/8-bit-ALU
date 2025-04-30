module control_unit (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [1:0] op_code,
    input wire [1:0] booth_bits,
    input wire booth_counter_done,
    input wire divider_sign_R,
    input wire divider_counter_done,
    output wire adder_en,
    output wire subtractor_en,
    output wire booth_load,
    output wire booth_add_en,
    output wire booth_sub_en,
    output wire booth_shift_en,
    output wire booth_count_en,
    output wire divider_load,
    output wire divider_add_en,
    output wire divider_sub_en,
    output wire divider_shift_en,
    output wire divider_count_en,
    output wire divider_final_add,
    output wire alu_done
);

    // ========================
    // STATE ENCODING
    // ========================
    wire [17:0] current_state;
    wire [17:0] pre_reset_next_state;
    wire [17:0] reset_muxed_state;

    wire IDLE, LOAD, ADD_EXEC, SUB_EXEC, MUL_LOAD, MUL_CHECK, MUL_ADD, MUL_SUB, MUL_SHIFT;
    wire MUL_COUNT, MUL_DONE, DIV_LOAD, DIV_SHIFT, DIV_OP, DIV_COUNT, DIV_FINAL_CORR, DIV_DONE, DONE;

    assign IDLE           = current_state[0];
    assign LOAD           = current_state[1];
    assign ADD_EXEC       = current_state[2];
    assign SUB_EXEC       = current_state[3];
    assign MUL_LOAD       = current_state[4];
    assign MUL_CHECK      = current_state[5];
    assign MUL_ADD        = current_state[6];
    assign MUL_SUB        = current_state[7];
    assign MUL_SHIFT      = current_state[8];
    assign MUL_COUNT      = current_state[9];
    assign MUL_DONE       = current_state[10];
    assign DIV_LOAD       = current_state[11];
    assign DIV_SHIFT      = current_state[12];
    assign DIV_OP         = current_state[13];
    assign DIV_COUNT      = current_state[14];
    assign DIV_FINAL_CORR = current_state[15];
    assign DIV_DONE       = current_state[16];
    assign DONE           = current_state[17];

    // ==========================
    // INPUT DECODE (GATES ONLY)
    // ==========================
    wire not_start, not_op0, not_op1, not_booth0, not_booth1;
    wire op00, op01, op10, op11;
    wire booth_00, booth_01, booth_10, booth_11;
    wire not_booth_counter_done, not_divider_counter_done, not_divider_sign_R;
    wire not_reset;

    not (not_start, start);
    not (not_op0, op_code[0]);
    not (not_op1, op_code[1]);
    not (not_booth0, booth_bits[0]);
    not (not_booth1, booth_bits[1]);
    not (not_booth_counter_done, booth_counter_done);
    not (not_divider_counter_done, divider_counter_done);
    not (not_divider_sign_R, divider_sign_R);
    not (not_reset, reset);

    and (op00, not_op1, not_op0);
    and (op01, not_op1, op_code[0]);
    and (op10, op_code[1], not_op0);
    and (op11, op_code[1], op_code[0]);

    and (booth_00, not_booth1, not_booth0);
    and (booth_01, not_booth1, booth_bits[0]);
    and (booth_10, booth_bits[1], not_booth0);
    and (booth_11, booth_bits[1], booth_bits[0]);

    // ==========================
    // NEXT STATE PURE GATES
    // ==========================

    wire idle_hold, done_to_idle;
    wire idle_to_load;
    wire load_to_add, load_to_sub, load_to_mul, load_to_div;
    wire mul_load_to_check, mul_count_to_check;
    wire mul_check_to_add, mul_check_to_sub, mul_check_to_shift;
    wire div_load_to_shift, div_count_to_shift;

    and (idle_hold, IDLE, not_start);
    and (done_to_idle, DONE, 1'b1);
    and (idle_to_load, IDLE, start);

    and (load_to_add, LOAD, op00);
    and (load_to_sub, LOAD, op01);
    and (load_to_mul, LOAD, op10);
    and (load_to_div, LOAD, op11);

    and (mul_load_to_check, MUL_LOAD, 1'b1);
    and (mul_count_to_check, MUL_COUNT, not_booth_counter_done);

    and (mul_check_to_add, MUL_CHECK, booth_01);
    and (mul_check_to_sub, MUL_CHECK, booth_10);
    //and (mul_check_to_shift, MUL_CHECK, booth_00, booth_11);

    wire booth_shift_cond;
    or (booth_shift_cond, booth_00, booth_11);
    and (mul_check_to_shift, MUL_CHECK, booth_shift_cond);


    and (div_load_to_shift, DIV_LOAD, 1'b1);
    and (div_count_to_shift, DIV_COUNT, not_divider_counter_done);

    // ================
    // NEXT STATES
    // ================

    wire pre_IDLE, pre_LOAD, pre_ADD_EXEC, pre_SUB_EXEC, pre_MUL_LOAD, pre_MUL_CHECK;
    wire pre_MUL_ADD, pre_MUL_SUB, pre_MUL_SHIFT, pre_MUL_COUNT, pre_MUL_DONE;
    wire pre_DIV_LOAD, pre_DIV_SHIFT, pre_DIV_OP, pre_DIV_COUNT, pre_DIV_FINAL_CORR;
    wire pre_DIV_DONE, pre_DONE;

    or (pre_IDLE, idle_hold, done_to_idle);
    buf (pre_LOAD, idle_to_load);

    buf (pre_ADD_EXEC, load_to_add);
    buf (pre_SUB_EXEC, load_to_sub);

    buf (pre_MUL_LOAD, load_to_mul);
    or (pre_MUL_CHECK, mul_load_to_check, mul_count_to_check);

    buf (pre_MUL_ADD, mul_check_to_add);
    buf (pre_MUL_SUB, mul_check_to_sub);
    or (pre_MUL_SHIFT, mul_check_to_shift, MUL_ADD, MUL_SUB);

    buf (pre_MUL_COUNT, MUL_SHIFT);
    and (pre_MUL_DONE, MUL_COUNT, booth_counter_done);

    buf (pre_DIV_LOAD, load_to_div);
    or (pre_DIV_SHIFT, div_load_to_shift, div_count_to_shift);

    buf (pre_DIV_OP, DIV_SHIFT);
    buf (pre_DIV_COUNT, DIV_OP);
    and (pre_DIV_FINAL_CORR, DIV_COUNT, divider_counter_done);
    buf (pre_DIV_DONE, DIV_FINAL_CORR);

    or (pre_DONE, ADD_EXEC, SUB_EXEC, MUL_DONE, DIV_DONE);

    // ==========================
    // RESET MUX LOGIC
    // ==========================
    or (reset_muxed_state[0], pre_IDLE, reset);

    and (reset_muxed_state[1], pre_LOAD, not_reset);
    and (reset_muxed_state[2], pre_ADD_EXEC, not_reset);
    and (reset_muxed_state[3], pre_SUB_EXEC, not_reset);
    and (reset_muxed_state[4], pre_MUL_LOAD, not_reset);
    and (reset_muxed_state[5], pre_MUL_CHECK, not_reset);
    and (reset_muxed_state[6], pre_MUL_ADD, not_reset);
    and (reset_muxed_state[7], pre_MUL_SUB, not_reset);
    and (reset_muxed_state[8], pre_MUL_SHIFT, not_reset);
    and (reset_muxed_state[9], pre_MUL_COUNT, not_reset);
    and (reset_muxed_state[10], pre_MUL_DONE, not_reset);
    and (reset_muxed_state[11], pre_DIV_LOAD, not_reset);
    and (reset_muxed_state[12], pre_DIV_SHIFT, not_reset);
    and (reset_muxed_state[13], pre_DIV_OP, not_reset);
    and (reset_muxed_state[14], pre_DIV_COUNT, not_reset);
    and (reset_muxed_state[15], pre_DIV_FINAL_CORR, not_reset);
    and (reset_muxed_state[16], pre_DIV_DONE, not_reset);
    and (reset_muxed_state[17], pre_DONE, not_reset);

    // ==========================
    // STATE REGISTER
    // ==========================
    register #(18) state_reg (
        .clk(clk),
        .d(reset_muxed_state),
        .q(current_state)
    );

    // ==========================
    // OUTPUT LOGIC
    // ==========================
    buf (adder_en, ADD_EXEC);
    buf (subtractor_en, SUB_EXEC);

    buf (booth_load, MUL_LOAD);
    buf (booth_add_en, MUL_ADD);
    buf (booth_sub_en, MUL_SUB);
    buf (booth_shift_en, MUL_SHIFT);
    buf (booth_count_en, MUL_COUNT);

    buf (divider_load, DIV_LOAD);
    buf (divider_shift_en, DIV_SHIFT);
    and (divider_add_en, DIV_OP, divider_sign_R);
    and (divider_sub_en, DIV_OP, not_divider_sign_R);
    buf (divider_count_en, DIV_COUNT);
    buf (divider_final_add, DIV_FINAL_CORR);

    buf (alu_done, DONE);

endmodule


/*`timescale 1ns/1ps

module control_unit_tb;

    reg clk, reset, start;
    reg [1:0] op_code;
    reg [1:0] booth_bits;
    reg booth_counter_done;
    reg divider_sign_R;
    reg divider_counter_done;

    wire adder_en;
    wire subtractor_en;
    wire booth_load;
    wire booth_add_en;
    wire booth_sub_en;
    wire booth_shift_en;
    wire booth_count_en;
    wire divider_load;
    wire divider_add_en;
    wire divider_sub_en;
    wire divider_shift_en;
    wire divider_count_en;
    wire divider_final_add;
    wire alu_done;

    control_unit uut (
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

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns clock
    end

    initial begin
        // Monitor important signals
        $monitor("T=%0t | reset=%b start=%b op_code=%b | State=%b | ADDER=%b SUB=%b BOOTH_LOAD=%b DIV_LOAD=%b ALU_DONE=%b",
                 $time, reset, start, op_code, uut.current_state,
                 adder_en, subtractor_en, booth_load, divider_load, alu_done);


        // Initialize signals
        reset = 1;
        start = 0;
        op_code = 2'b00;
        booth_bits = 2'b00;
        booth_counter_done = 0;
        divider_sign_R = 0;
        divider_counter_done = 0;

        // ====== RESET PHASE ======
        #20 reset = 0; // Deassert reset

        // ====== ADD Test ======
        #10 start = 1; op_code = 2'b00; // ADD
        #10 start = 0;
        wait (alu_done); // Wait for operation to complete
        #20;

        // ====== SUB Test ======
        start = 1; op_code = 2'b01; // SUB
        #10 start = 0;
        wait (alu_done);
        #20;

        // ====== MUL (Booth) Test ======
        start = 1; op_code = 2'b10; // MUL
        #10 start = 0;

        // Booth bits sequence simulation
        #30 booth_bits = 2'b01; // MUL_ADD
        #20 booth_bits = 2'b00; // MUL_SHIFT
        #20 booth_bits = 2'b10; // MUL_SUB
        #20 booth_bits = 2'b00; // MUL_SHIFT
        #20 booth_counter_done = 1; // Final booth count done
        #20 booth_counter_done = 0;
        wait (alu_done);
        #20;

        // ====== DIV (Divider) Test ======
        start = 1; op_code = 2'b11; // DIV
        #10 start = 0;

        // Divider operation simulation
        #30 divider_sign_R = 1; // simulate R negative for ADD
        #20 divider_sign_R = 0; // simulate R positive for SUB

        // After enough time for few DIV_COUNT loops
        #100; // << add this wait (100ns is fine)

        // Then raise divider_counter_done to escape the loop
        divider_counter_done = 1;
        #20 divider_counter_done = 0;

        wait (alu_done);
        #20;

        $display("Simulation finished.");
        $stop;
    end

endmodule*/


