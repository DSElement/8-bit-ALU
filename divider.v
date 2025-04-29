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
    output wire [15:0] reg_data
);

    wire [15:0] internal_reg_data;
    wire [15:0] shifted_data;
    wire [7:0] addsub_result;
    wire [15:0] final_corrected_data;
    wire [2:0] count;

    wire sign_rem;
    wire [15:0] load_value;
    //wire [15:0] addsub_concat;
    wire [15:0] selected_shift;
    wire [15:0] selected_addsub;
    wire [15:0] selected_load;
    wire [15:0] selected_final_add;
    wire [15:0] selected_reset;

    wire nreset, nload, nadd_en, nsub_en, nshift_en, nfinal_add;

    // Wires
    assign load_value = {8'b0, dividend};
    assign sign_rem = internal_reg_data[15];
    //assign addsub_concat = {addsub_result, internal_reg_data[7:1], ~addsub_result[7]};
wire [15:0] addsub_concat;
wire naddsub7;

not (naddsub7, addsub_result[7]);

assign addsub_concat[15:8] = addsub_result[7:0];
assign addsub_concat[7:1] = internal_reg_data[7:1];
assign addsub_concat[0] = naddsub7;


    not (nreset, reset);
    not (nload, load);
    not (nadd_en, add_en);
    not (nsub_en, sub_en);
    not (nshift_en, shift_en);
    not (nfinal_add, final_add);

    // Adder/subtracter for main work
    add_sub #(8) addsub_inst (
        .a(internal_reg_data[15:8]),
        .b(divisor),
        .sub(sub_en),
        .sum(addsub_result)
    );

    // Adder for final correction
    add_sub #(8) final_addsub_inst (
        .a(internal_reg_data[15:8]),
        .b(divisor),
        .sub(1'b0),
        .sum(final_corrected_data[15:8])
    );

    assign final_corrected_data[7:0] = internal_reg_data[7:0]; // Hardwire low bits

    // Shifter for left shift
    shifter #(16) shifter_inst (
        .in(internal_reg_data),
        .direction(1'b1), // left shift
        .out(shifted_data)
    );

    // Counter
    counter #(3) counter_inst (
        .clk(clk),
        .reset(reset),
        .enable(count_en),
        .count(count)
    );

    // ========== next_reg_data MUX Chain ==========

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : mux_chain

            wire shift_path, hold_path;
            and (shift_path, shifted_data[i], shift_en);
            and (hold_path, internal_reg_data[i], nshift_en);
            or (selected_shift[i], shift_path, hold_path);

            wire addsub_path, shift_hold_path;
            and (addsub_path, addsub_concat[i], (add_en | sub_en));
            and (shift_hold_path, selected_shift[i], ~(add_en | sub_en));
            or (selected_addsub[i], addsub_path, shift_hold_path);

            wire load_path, addsub_shift_path;
            and (load_path, load_value[i], load);
            and (addsub_shift_path, selected_addsub[i], nload);
            or (selected_load[i], load_path, addsub_shift_path);

            wire final_path, load_addsub_shift_path;
            and (final_path, final_corrected_data[i], final_add & sign_rem);
            and (load_addsub_shift_path, selected_load[i], ~(final_add & sign_rem));
            or (selected_final_add[i], final_path, load_addsub_shift_path);

            wire reset_zero, normal_path;
            and (reset_zero, 1'b0, reset); // forced zero
            and (normal_path, selected_final_add[i], nreset);
            or (selected_reset[i], reset_zero, normal_path);
        end
    endgenerate

    // Register
    register #(16) reg_RQ (
        .clk(clk),
        .d(selected_reset),
        .q(internal_reg_data)
    );

    assign quotient = internal_reg_data[7:0];
    assign remainder = internal_reg_data[15:8];
    assign done = (count == 3'b111);
    assign reg_data = internal_reg_data;

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


