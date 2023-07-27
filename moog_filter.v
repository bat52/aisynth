// 
// can you design a verilog digital filter implementing a resonant moog filter 
// model with 16 bits reulution and audio sampling frequency of 44.1khz?
//
// can you do the same but using input signals instead of parameters 
// for CUTOFF, RESONANCE and GAIN?
//
// please reduce cutoff resonance and gain width to 8 bits of resolution. 
// does this have an impact on filter quality and stability?

module MoogFilter (
  input clk,
  input [15:0] audio_in,
  input [7:0] cutoff,
  input [7:0] resonance,
  input [7:0] gain,
  output reg [15:0] audio_out
);

  // Internal signals
  reg [15:0] stage1, stage2, stage3, stage4;
  reg [15:0] delay1, delay2, delay3, delay4;
  reg [15:0] lowpass, bandpass, highpass;
  reg [15:0] feedback;

  // Constants
  parameter [15:0] ONE = 16'h7FFF;       // 1.0 in fixed-point format
  parameter [15:0] HALF = 16'h4000;      // 0.5 in fixed-point format

  // Calculate filter coefficients based on sampling frequency and input parameters
  reg [15:0] f, p, k;
  always @*
  begin
    f = (cutoff << 9) / 44100;
    p = f * (1.8 - 0.8 * f);
    k = p + p - 1;
  end

  // Update filter stages
  always @(posedge clk)
  begin
    stage1 = (audio_in - delay4) - ((delay1 * k) >> 15);
    stage1 = stage1 - ((delay1 * p) >> 15);
    stage2 = (delay1 + stage1) >> 1;
    stage3 = (stage1 + stage2) >> 1;
    stage4 = (stage2 + stage3) >> 1;

    lowpass = ((delay4 + stage4) >> 1) * gain;
    bandpass = ((stage1 - delay1) >> 1) * gain;
    highpass = (audio_in - lowpass - (bandpass * resonance) >> 15) * gain;

    feedback = highpass + (delay4 * resonance) >> 15;
    delay1 <= stage1;
    delay2 <= stage2;
    delay3 <= stage3;
    delay4 <= stage4;
  end

  // Output audio signal
  always @(posedge clk)
  begin
    audio_out <= (lowpass + highpass) >> 1;
  end

endmodule
