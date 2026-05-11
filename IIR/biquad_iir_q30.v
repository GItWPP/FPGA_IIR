module biquad_iir_q30
#(
    parameter signed [31:0] B0 = 32'sd0,
    parameter signed [31:0] B1 = 32'sd0,
    parameter signed [31:0] B2 = 32'sd0,
    parameter signed [31:0] A1 = 32'sd0,
    parameter signed [31:0] A2 = 32'sd0
)(
    input  wire               sys_clk,
    input  wire               sys_rst_n,

    input  wire signed [47:0] sample_in,
    input  wire               valid_in,

    output reg  signed [47:0] sample_out,
    output reg                valid_out
);

    localparam integer SAMPLE_WIDTH = 48;
    localparam integer COEFF_WIDTH  = 32;
    localparam integer FRAC         = 30;
    localparam integer MULT_WIDTH   = SAMPLE_WIDTH + COEFF_WIDTH;
    localparam integer ACC_WIDTH    = MULT_WIDTH + 4;

    localparam [2:0] ST_IDLE  = 3'd0;
    localparam [2:0] ST_MULB0 = 3'd1;
    localparam [2:0] ST_B0    = 3'd2;
    localparam [2:0] ST_B1    = 3'd3;
    localparam [2:0] ST_B2    = 3'd4;
    localparam [2:0] ST_A1    = 3'd5;
    localparam [2:0] ST_A2    = 3'd6;

    localparam signed [SAMPLE_WIDTH-1:0] SAMPLE_MAX =
        {1'b0, {(SAMPLE_WIDTH-1){1'b1}}};

    localparam signed [SAMPLE_WIDTH-1:0] SAMPLE_MIN =
        {1'b1, {(SAMPLE_WIDTH-1){1'b0}}};

    localparam signed [ACC_WIDTH-1:0] SAMPLE_MAX_ACC =
        {{(ACC_WIDTH-SAMPLE_WIDTH){1'b0}}, SAMPLE_MAX};

    localparam signed [ACC_WIDTH-1:0] SAMPLE_MIN_ACC =
        {{(ACC_WIDTH-SAMPLE_WIDTH){1'b1}}, SAMPLE_MIN};

    reg [2:0] state;

    reg signed [SAMPLE_WIDTH-1:0] x_reg;
    reg signed [SAMPLE_WIDTH-1:0] y_reg;

    reg signed [ACC_WIDTH-1:0] z1;
    reg signed [ACC_WIDTH-1:0] z2;

    reg signed [ACC_WIDTH-1:0] xb1_reg;
    reg signed [ACC_WIDTH-1:0] xb2_reg;
    reg signed [ACC_WIDTH-1:0] ya1_reg;

    (* use_dsp = "yes" *)
    reg signed [MULT_WIDTH-1:0] mul_p;

    wire signed [MULT_WIDTH-1:0] mul_shift;
    wire signed [ACC_WIDTH-1:0]  mul_q30;

    assign mul_shift = mul_p >>> FRAC;
    assign mul_q30   = {{(ACC_WIDTH-MULT_WIDTH){mul_shift[MULT_WIDTH-1]}}, mul_shift};

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            state      <= ST_IDLE;
            x_reg      <= {SAMPLE_WIDTH{1'b0}};
            y_reg      <= {SAMPLE_WIDTH{1'b0}};
            z1         <= {ACC_WIDTH{1'b0}};
            z2         <= {ACC_WIDTH{1'b0}};
            xb1_reg    <= {ACC_WIDTH{1'b0}};
            xb2_reg    <= {ACC_WIDTH{1'b0}};
            ya1_reg    <= {ACC_WIDTH{1'b0}};
            mul_p      <= {MULT_WIDTH{1'b0}};
            sample_out <= {SAMPLE_WIDTH{1'b0}};
            valid_out  <= 1'b0;
        end else begin
            valid_out <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (valid_in) begin
                        x_reg <= sample_in;
                        state <= ST_MULB0;
                    end
                end

                ST_MULB0: begin
                    mul_p <= x_reg * B0;
                    state <= ST_B0;
                end

                ST_B0: begin
                    y_reg <= sat_sample(mul_q30 + z1);
                    mul_p <= x_reg * B1;
                    state <= ST_B1;
                end

                ST_B1: begin
                    xb1_reg <= mul_q30;
                    mul_p   <= x_reg * B2;
                    state   <= ST_B2;
                end

                ST_B2: begin
                    xb2_reg <= mul_q30;
                    mul_p   <= y_reg * A1;
                    state   <= ST_A1;
                end

                ST_A1: begin
                    ya1_reg <= mul_q30;
                    mul_p   <= y_reg * A2;
                    state   <= ST_A2;
                end

                ST_A2: begin
                    z1         <= xb1_reg + z2 - ya1_reg;
                    z2         <= xb2_reg - mul_q30;
                    sample_out <= y_reg;
                    valid_out  <= 1'b1;
                    state      <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

    function signed [SAMPLE_WIDTH-1:0] sat_sample;
        input signed [ACC_WIDTH-1:0] x;
        begin
            if (x > SAMPLE_MAX_ACC)
                sat_sample = SAMPLE_MAX;
            else if (x < SAMPLE_MIN_ACC)
                sat_sample = SAMPLE_MIN;
            else
                sat_sample = x[SAMPLE_WIDTH-1:0];
        end
    endfunction

endmodule
