module booth (
    input wire clk,
    input wire reset,
    input wire load,      // load multiplicand and multiplier
    input wire shift_en,  // shift enable
    input wire add_en,    // addition enable
    input wire sub_en,    // subtraction enable
    input wire count_en,  // counter enable
    input wire [7:0] multiplicand,
    input wire [7:0] multiplier,
    output wire [15:0] product,
    output wire done,
    output wire [16:0] reg_data
);

    wire [16:0] internal_reg_data;
    wire [16:0] shifted_data;
    wire [7:0] addsub_result;
    wire [2:0] count;

    wire [16:0] load_value;
    wire [16:0] addsub_concat;
    wire [16:0] selected_shift;
    wire [16:0] selected_addsub;
    wire [16:0] selected_load;
    wire [16:0] selected_reset;
    wire nreset, nload, nadd_en, nsub_en, nshift_en;

    assign load_value = {8'b0, multiplier, 1'b0};
    assign addsub_concat = {addsub_result, internal_reg_data[8:0]};

    not (nreset, reset);
    not (nload, load);
    not (nadd_en, add_en);
    not (nsub_en, sub_en);
    not (nshift_en, shift_en);

    // Parallel adder/subtractor
    add_sub #(8) addsub_inst (
        .a(internal_reg_data[16:9]),
        .b(multiplicand),
        .sub(sub_en),
        .sum(addsub_result)
    );

    // Right arithmetic shifter
    shifter #(17) shifter_inst (
        .in(internal_reg_data),
        .direction(1'b0), // Right shift
        .out(shifted_data)
    );

    // Counter
    counter #(3) count_inst (
        .clk(clk),
        .reset(reset),
        .enable(count_en),
        .count(count)
    );

    // ===================
    // Build next_reg_data
    // ===================

    genvar i;
    generate
        for (i = 0; i < 17; i = i + 1) begin : mux_chain

            // First select between shift or hold
            wire shift_path, hold_path;
            and (shift_path, shifted_data[i], shift_en);
            and (hold_path, internal_reg_data[i], nshift_en);
            or (selected_shift[i], shift_path, hold_path);

            // Then select between addsub or (shift/hold)
            wire addsub_path, shift_hold_path;
            and (addsub_path, addsub_concat[i], (add_en | sub_en));
            and (shift_hold_path, selected_shift[i], ~(add_en | sub_en));
            or (selected_addsub[i], addsub_path, shift_hold_path);

            // Then select between load or (addsub/shift/hold)
            wire load_path, addsub_shift_path;
            and (load_path, load_value[i], load);
            and (addsub_shift_path, selected_addsub[i], nload);
            or (selected_load[i], load_path, addsub_shift_path);

            // Finally select between reset or (load/addsub/shift/hold)
            wire reset_zero, normal_path;
            and (reset_zero, 1'b0, reset); // always zero when reset
            and (normal_path, selected_load[i], nreset);
            or (selected_reset[i], reset_zero, normal_path);

        end
    endgenerate

    // ===================
    // Register
    // ===================

    register #(17) reg_AQ (
        .clk(clk),
        .d(selected_reset),
        .q(internal_reg_data)
    );

    assign done = (count == 3'b111);
    assign product = internal_reg_data[16:1];
    assign reg_data = internal_reg_data;

endmodule



/*`timescale 1ns/1ps

module booth_tb;

    reg clk;
    reg reset;
    reg load;
    reg shift_en;
    reg add_en;
    reg sub_en;
    reg count_en;
    reg [7:0] multiplicand;
    reg [7:0] multiplier;
    wire [15:0] product;
    wire done;
    wire [16:0] reg_data; // observe internal reg if needed

    booth DUT (
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
        .reg_data(reg_data)
    );

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns clock
    end

    // Test sequence
    initial begin
        //$display("Time | A | B | Product | reg_data | done");
        //$monitor("%4t | %d | %d | %d | %b | %b", $time, multiplicand, multiplier, product, reg_data, done);
	$monitor("%4t | %d * %d = %d | A=%b Q=%b Q-1=%b | %b", 
        $time, multiplicand, multiplier, product, 
        reg_data[16:9], reg_data[8:1], reg_data[0], 
        done);

        // Reset
        reset = 1; load = 0; shift_en = 0; add_en = 0; sub_en = 0; count_en = 0;
        multiplicand = 0; multiplier = 0;
        #20;
        reset = 0;

        // ==============
        // Test:  5 * 3
        // ==============
        multiplicand = 8'b11111011;
        multiplier   = 8'b00000011;

        // Step 1: Load
        load = 1;
        #10;
        load = 0;

        // Booth Algorithm steps
        repeat (8) begin
            case ({reg_data[1], reg_data[0]}) // {Q0, Q-1}
                2'b01: begin
                    add_en = 1;
                    #10;
                    add_en = 0;
                end
                2'b10: begin
                    sub_en = 1;
                    #10;
                    sub_en = 0;
                end
                default: begin
                    // No operation
                    #10;
                end
            endcase

	    #40
            // Shift
            shift_en = 1;
            count_en = 1;
            #10;
            shift_en = 0;
            count_en = 0;
        end

        // Wait few cycles
        #50;

        $stop;
    end

endmodule*/
