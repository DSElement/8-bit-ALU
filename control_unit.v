module control_unit (
    input wire clk,
    input wire reset,
    input wire begin_op,
    input wire [1:0] opcode,    // 00 = add, 01 = sub, 10 = mul, 11 = div
    input wire booth_done,
    input wire div_done,
    input wire booth_Q0,
    input wire booth_Qm1,
    input wire div_R_sign,
    output wire booth_load,
    output wire booth_shift_en,
    output wire booth_add_en,
    output wire booth_sub_en,
    output wire booth_count_en,
    output wire div_load,
    output wire div_shift_en,
    output wire div_add_en,
    output wire div_sub_en,
    output wire div_final_add,
    output wire div_count_en,
    output wire alu_done
);

    // One-hot State Encoding
    wire IDLE, MUL_LOAD, MUL_OP, MUL_SHIFT, MUL_DONE;
    wire DIV_LOAD, DIV_SHIFT, DIV_OP, DIV_FINAL, DIV_DONE;

    // Next state wires
    wire next_IDLE, next_MUL_LOAD, next_MUL_OP, next_MUL_SHIFT, next_MUL_DONE;
    wire next_DIV_LOAD, next_DIV_SHIFT, next_DIV_OP, next_DIV_FINAL, next_DIV_DONE;

    wire unused_qn[9:0]; // dummy wires for qn outputs

    // State Registers (one DFF per state)
    dff dff_IDLE     (.clk(clk), .reset(reset), .d(next_IDLE),      .q(IDLE),     .qn(unused_qn[0]));
    dff dff_MUL_LOAD (.clk(clk), .reset(reset), .d(next_MUL_LOAD),   .q(MUL_LOAD), .qn(unused_qn[1]));
    dff dff_MUL_OP   (.clk(clk), .reset(reset), .d(next_MUL_OP),     .q(MUL_OP),   .qn(unused_qn[2]));
    dff dff_MUL_SHIFT(.clk(clk), .reset(reset), .d(next_MUL_SHIFT),  .q(MUL_SHIFT),.qn(unused_qn[3]));
    dff dff_MUL_DONE (.clk(clk), .reset(reset), .d(next_MUL_DONE),   .q(MUL_DONE), .qn(unused_qn[4]));
    dff dff_DIV_LOAD (.clk(clk), .reset(reset), .d(next_DIV_LOAD),   .q(DIV_LOAD), .qn(unused_qn[5]));
    dff dff_DIV_SHIFT(.clk(clk), .reset(reset), .d(next_DIV_SHIFT),  .q(DIV_SHIFT),.qn(unused_qn[6]));
    dff dff_DIV_OP   (.clk(clk), .reset(reset), .d(next_DIV_OP),     .q(DIV_OP),   .qn(unused_qn[7]));
    dff dff_DIV_FINAL(.clk(clk), .reset(reset), .d(next_DIV_FINAL),  .q(DIV_FINAL),.qn(unused_qn[8]));
    dff dff_DIV_DONE (.clk(clk), .reset(reset), .d(next_DIV_DONE),   .q(DIV_DONE), .qn(unused_qn[9]));

    // ===============================
    // Next State Logic
    // ===============================

    // IDLE Transitions
    assign next_MUL_LOAD = IDLE & begin_op & (opcode == 2'b10);
    assign next_DIV_LOAD = IDLE & begin_op & (opcode == 2'b11);
    assign next_IDLE = (MUL_DONE | DIV_DONE);

    // Multiplication Transitions
    assign next_MUL_OP = MUL_LOAD | (MUL_SHIFT & ~booth_done);
    assign next_MUL_SHIFT = MUL_OP;
    assign next_MUL_DONE = MUL_SHIFT & booth_done;

    // Division Transitions
    assign next_DIV_SHIFT = DIV_LOAD | (DIV_OP & ~div_done);
    assign next_DIV_OP = DIV_SHIFT;
    assign next_DIV_FINAL = DIV_OP & div_done;
    assign next_DIV_DONE = DIV_FINAL;

    // ===============================
    // Outputs based on current state + conditions
    // ===============================

    assign booth_load     = MUL_LOAD;
    assign booth_shift_en = MUL_SHIFT;
    assign booth_count_en = MUL_SHIFT;

    // Booth Add/Sub Control
    assign booth_add_en = MUL_OP & (~booth_Q0 & booth_Qm1); // 01 => Add
    assign booth_sub_en = MUL_OP & (booth_Q0 & ~booth_Qm1); // 10 => Sub

    assign div_load       = DIV_LOAD;
    assign div_shift_en   = DIV_SHIFT;
    assign div_count_en   = DIV_SHIFT;

    // Divider Add/Sub Control
    assign div_sub_en = DIV_OP & ~div_R_sign; // R >= 0 => Subtract
    assign div_add_en = DIV_OP & div_R_sign;  // R < 0  => Add

    assign div_final_add  = DIV_FINAL;
    assign alu_done       = MUL_DONE | DIV_DONE;

endmodule


/*module control_unit (
    input wire clk,
    input wire reset,
    input wire begin_op,
    input wire [1:0] opcode,    // 00 = add, 01 = sub, 10 = mul, 11 = div
    input wire booth_done,
    input wire div_done,
    input wire booth_Q0,
    input wire booth_Qm1,
    input wire div_R_sign,
    output wire booth_load,
    output wire booth_shift_en,
    output wire booth_add_en,
    output wire booth_sub_en,
    output wire booth_count_en,
    output wire div_load,
    output wire div_shift_en,
    output wire div_add_en,
    output wire div_sub_en,
    output wire div_final_add,
    output wire div_count_en,
    output wire alu_done
);

    // One-hot State Encoding
    wire IDLE, MUL_LOAD, MUL_OP, MUL_SHIFT, MUL_DONE;
    wire DIV_LOAD, DIV_SHIFT, DIV_OP, DIV_FINAL, DIV_DONE;

    // Next state wires
    wire next_IDLE, next_MUL_LOAD, next_MUL_OP, next_MUL_SHIFT, next_MUL_DONE;
    wire next_DIV_LOAD, next_DIV_SHIFT, next_DIV_OP, next_DIV_FINAL, next_DIV_DONE;

    // State Registers (one DFF per state)
    dff dff_IDLE(clk, reset ? 1'b1 : next_IDLE, IDLE);
    dff dff_MUL_LOAD(clk, reset ? 1'b0 : next_MUL_LOAD, MUL_LOAD);
    dff dff_MUL_OP(clk, reset ? 1'b0 : next_MUL_OP, MUL_OP);
    dff dff_MUL_SHIFT(clk, reset ? 1'b0 : next_MUL_SHIFT, MUL_SHIFT);
    dff dff_MUL_DONE(clk, reset ? 1'b0 : next_MUL_DONE, MUL_DONE);
    dff dff_DIV_LOAD(clk, reset ? 1'b0 : next_DIV_LOAD, DIV_LOAD);
    dff dff_DIV_SHIFT(clk, reset ? 1'b0 : next_DIV_SHIFT, DIV_SHIFT);
    dff dff_DIV_OP(clk, reset ? 1'b0 : next_DIV_OP, DIV_OP);
    dff dff_DIV_FINAL(clk, reset ? 1'b0 : next_DIV_FINAL, DIV_FINAL);
    dff dff_DIV_DONE(clk, reset ? 1'b0 : next_DIV_DONE, DIV_DONE);

    // ===============================
    // Next State Logic
    // ===============================

    // IDLE Transitions
    assign next_MUL_LOAD = IDLE & begin_op & (opcode == 2'b10);
    assign next_DIV_LOAD = IDLE & begin_op & (opcode == 2'b11);
    assign next_IDLE = (MUL_DONE | DIV_DONE);

    // Multiplication Transitions
    assign next_MUL_OP = MUL_LOAD | (MUL_SHIFT & ~booth_done);
    assign next_MUL_SHIFT = MUL_OP;
    assign next_MUL_DONE = MUL_SHIFT & booth_done;

    // Division Transitions
    assign next_DIV_SHIFT = DIV_LOAD | (DIV_OP & ~div_done);
    assign next_DIV_OP = DIV_SHIFT;
    assign next_DIV_FINAL = DIV_OP & div_done;
    assign next_DIV_DONE = DIV_FINAL;

    // ===============================
    // Outputs based on current state + conditions
    // ===============================

    assign booth_load     = MUL_LOAD;
    assign booth_shift_en = MUL_SHIFT;
    assign booth_count_en = MUL_SHIFT;

    // Booth Add/Sub Control
    assign booth_add_en = MUL_OP & (~booth_Q0 & booth_Qm1); // 01 => Add
    assign booth_sub_en = MUL_OP & (booth_Q0 & ~booth_Qm1); // 10 => Sub

    assign div_load       = DIV_LOAD;
    assign div_shift_en   = DIV_SHIFT;
    assign div_count_en   = DIV_SHIFT;

    // Divider Add/Sub Control
    assign div_sub_en = DIV_OP & ~div_R_sign; // R >= 0 => Subtract
    assign div_add_en = DIV_OP & div_R_sign;  // R < 0  => Add

    assign div_final_add  = DIV_FINAL;
    assign alu_done       = MUL_DONE | DIV_DONE;

endmodule*/

/*
// ==============================
// DFF Module (structural)
// ==============================
module dff (
    input wire clk,
    input wire d,
    output wire q
);

    reg q_reg;
    assign q = q_reg;

    always @(posedge clk)
        q_reg <= d;

endmodule
*/
