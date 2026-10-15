`timescale 1ns/1ps

/*
 * Nine-lane parallel piecewise-cubic spline evaluator.
 * Synthesizable Verilog-2001.
 *
 * S(t) = ((a*t + b)*t + c)*t + d
 * Inputs and coefficients use signed fixed-point Q*.FRAC format.
 * Each lane has one independently inferred coefficient-memory bank and
 * one multiplier reused across the three Horner steps.
 */
module parallel_cubic_spline #(
    parameter LANES        = 9,
    parameter WIDTH        = 16,
    parameter FRAC         = 8,
    parameter NUM_SEGMENTS = 16,
    parameter SEG_WIDTH    = 4,
    parameter LANE_WIDTH   = 4
)(
    input                              clk,
    input                              rst_n,

    input                              start,
    input      [(LANES*WIDTH)-1:0]     x_data,
    output reg                         busy,
    output reg                         done,
    output     [(LANES*WIDTH)-1:0]     spline_data,

    /* Program coefficient memory only while the evaluator is idle. */
    input                              coeff_we,
    input      [SEG_WIDTH-1:0]         coeff_addr,
    input      [LANE_WIDTH-1:0]        coeff_lane,
    input      [(4*WIDTH)-1:0]         coeff_wdata
);

    localparam ST_IDLE    = 3'd0;
    localparam ST_READ    = 3'd1;
    localparam ST_HORNER2 = 3'd2;
    localparam ST_HORNER3 = 3'd3;
    localparam ST_WRITE   = 3'd4;

    reg [2:0] state;
    wire coeff_lane_valid;

    /* Four selector bits encode 0..15; only lane numbers 0..8 are valid. */
    assign coeff_lane_valid = (coeff_lane < LANES);

    genvar lane;
    generate
        for (lane = 0; lane < LANES; lane = lane + 1) begin : G_SPLINE_LANE

            reg [(4*WIDTH)-1:0] coefficient_memory [0:NUM_SEGMENTS-1];
            reg [(4*WIDTH)-1:0] coefficient_word;

            wire signed [WIDTH-1:0] x_lane;
            wire [SEG_WIDTH-1:0] segment_index;
            wire signed [WIDTH-1:0] local_t;

            reg signed [WIDTH-1:0] t_reg;
            reg signed [WIDTH-1:0] accumulator;
            reg signed [WIDTH-1:0] result_reg;

            wire signed [WIDTH-1:0] coeff_a;
            wire signed [WIDTH-1:0] coeff_b;
            wire signed [WIDTH-1:0] coeff_c;
            wire signed [WIDTH-1:0] coeff_d;

            reg  signed [WIDTH-1:0] multiply_left;
            wire signed [(2*WIDTH)-1:0] full_product;
            wire signed [WIDTH-1:0] scaled_product;

            assign x_lane = x_data[(lane*WIDTH) +: WIDTH];

            /* Unit-spaced knots: integer bits select the spline segment. */
            assign segment_index = x_lane[FRAC +: SEG_WIDTH];
            assign local_t = {{(WIDTH-FRAC){1'b0}}, x_lane[FRAC-1:0]};

            assign coeff_a = coefficient_word[(4*WIDTH)-1 -: WIDTH];
            assign coeff_b = coefficient_word[(3*WIDTH)-1 -: WIDTH];
            assign coeff_c = coefficient_word[(2*WIDTH)-1 -: WIDTH];
            assign coeff_d = coefficient_word[(1*WIDTH)-1 -: WIDTH];

            assign full_product = multiply_left * t_reg;
            assign scaled_product = full_product >>> FRAC;
            assign spline_data[(lane*WIDTH) +: WIDTH] = result_reg;

            /* One multiplier per lane, reused across all Horner stages. */
            always @(*) begin
                if (state == ST_READ)
                    multiply_left = coeff_a;
                else
                    multiply_left = accumulator;
            end

            /* Synchronous coefficient-bank read and programming write. */
            always @(posedge clk) begin
                if (coeff_we && !busy && coeff_lane_valid &&
                    (coeff_lane == lane))
                    coefficient_memory[coeff_addr] <= coeff_wdata;

                if ((state == ST_IDLE) && start && !busy)
                    coefficient_word <= coefficient_memory[segment_index];
            end

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    t_reg       <= {WIDTH{1'b0}};
                    accumulator <= {WIDTH{1'b0}};
                    result_reg  <= {WIDTH{1'b0}};
                end
                else begin
                    if ((state == ST_IDLE) && start && !busy)
                        t_reg <= local_t;

                    case (state)
                        ST_READ:
                            accumulator <= scaled_product + coeff_b;

                        ST_HORNER2:
                            accumulator <= scaled_product + coeff_c;

                        ST_HORNER3:
                            accumulator <= scaled_product + coeff_d;

                        ST_WRITE:
                            result_reg <= accumulator;

                        default: begin
                            accumulator <= accumulator;
                            result_reg  <= result_reg;
                        end
                    endcase
                end
            end
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            busy  <= 1'b0;
            done  <= 1'b0;
        end
        else begin
            done <= 1'b0;

            case (state)
                ST_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy  <= 1'b1;
                        state <= ST_READ;
                    end
                end

                ST_READ:
                    state <= ST_HORNER2;

                ST_HORNER2:
                    state <= ST_HORNER3;

                ST_HORNER3:
                    state <= ST_WRITE;

                ST_WRITE: begin
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                    busy  <= 1'b0;
                end
            endcase
        end
    end

endmodule
