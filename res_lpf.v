// can you write from scratch a resonant low pass filter in verilog with signed input of 16bit ?

// note output is a reserved keyword, and cannot be used as a register name

// add a reset signal, active low

// add $signed to both sides of comparisons, and right side of assignments

module ResonantLowPassFilter(
    input clk,
    input signed [15:0] audio_in,
    input signed [15:0] cutoff,
    input signed [15:0] resonance,
    input signed [15:0] gain,
    input reset_n,
    output reg signed [15:0] filtered_audio
);

    // Constants
    parameter [15:0] MAX_POS_VALUE = 16'h7FFF;
    parameter [15:0] MIN_NEG_VALUE = -16'h8000;

    // Internal registers
    reg signed [15:0] state;
    reg signed [15:0] feedback;
    reg signed [15:0] output_reg;

    // Calculate coefficients
    reg signed [15:0] alpha;
    reg signed [15:0] beta;
    reg signed [15:0] gamma;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= $signed(16'h0000);
            feedback <= $signed(16'h0000);
            output_reg <= $signed(16'h0000);
        end else begin
            // Calculate coefficients based on cutoff and resonance
            alpha <= $signed(cutoff);
            beta <= $signed(resonance);
            gamma <= $signed(gain);

            // Calculate feedback signal and limit it to the output range
            feedback <= ($signed(state) * $signed(beta)) >> 15;
            if (feedback > $signed(MAX_POS_VALUE))
                feedback <= $signed(MAX_POS_VALUE);
            else if (feedback < $signed(MIN_NEG_VALUE))
                feedback <= $signed(MIN_NEG_VALUE);

            // Update state and filtered_audio
            state <= $signed(audio_in) - feedback;
            output_reg <= ($signed(state) * $signed(alpha)) >> 15;
            filtered_audio <= output_reg + ($signed(gamma) >> 1); // Apply gain and round off
        end
    end

endmodule

