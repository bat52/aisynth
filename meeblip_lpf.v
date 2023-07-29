// It follows a definition of a resonant lowpass filter in assembler for AVR microcontrollers. 
// Can you translate this into verilog ? 

// ;----------------------------------------------------------------------------
// ; DCF:
// ;----------------------------------------------------------------------------

// ;----------------------------------------------------------------------------
// ; Digitally Controlled Filter
// ;
// ; A 2-pole resonant low pass filter:
// ;
// ; a += f * ((in - a) + q * 4 * (a - b))
// ; b += f * (a - b)
// ;
// ; f = (1-F)/2+Q_offset
// ; q = Q-f = Q-(1-F)/2+Q_offset
// ;
// ; F = LPF (cutoff)
// ; Q = RESONANCE
// ; q = SCALED_RESONANCE
// ; b => output
// ;
// ; Input 16-Bit signed HDAC:LDAC (r17:r16), already scaled to minimize clipping (reduced to 25% of full code).
// ;
// ;----------------------------------------------------------------------------
// ; see also
// ;   http://www.kvraudio.com/forum/printview.php?t=225711
// ;----------------------------------------------------------------------------

// 	; calc (in - a) ; both signed
// 	sub	LDAC, a_L
// 	sbc	HDAC, a_H
// 					; check for overflow / do hard clipping
// 	brvc	OVERFLOW_1		; if overflow bit is clear jump to OVERFLOW_1
// 					; sub overflow happened -> set to min
// 					; 0b1000.0000 0b0000.0001 -> min
// 					; 0b0111.1111 0b1111.1111 -> max
// 	ldi	LDAC, 0b00000001
// 	ldi	HDAC, 0b10000000
// OVERFLOW_1:				; when overflow is clear

// 					; (in-a) is now in HDAC:LDAC as signed
// 					; now calc q*(a-b)
// 	lds	r22, SCALED_RESONANCE	; load filter Q value, unsigned
// OVERFLOW_2:

// 	mov	r20, a_L		; \
// 	mov	r21, a_H		; / load 'a' , signed
// 	lds	z_H, b_H		; \
// 	lds	z_L, b_L		; / load 'b', signed
// 	sub	r20, z_L		; \
// 	sbc	r21, z_H		; / (a-b) signed
// 	brvc	OVERFLOW_3		; if overflow is clear jump to OVERFLOW_3
// 					; 0b1000.0000 0b0000.0001 -> min
// 					; 0b0111.1111 0b1111.1111 -> max
// 	ldi	r20, 0b00000001
// 	ldi	r21, 0b10000000
// OVERFLOW_3:

// 	lds	r18, PATCH_SWITCH1	; Check Low Pass/High Pass panel switch.
// 	sbrs	r18, SW_FILTER_MODE
// 	rjmp	CALC_LOWPASS

// SKIP_REZ:
// 	movw	z_L, r20		; High Pass selected, so just load r21:r20 into z_H:z_L to disable Q
// 	rjmp	DCF_ADD			; Skip lowpass calc

// CALC_LOWPASS:
// 	; skip resonance calculation if VCF is turned off (value of 0)
// 	lds	r18, VCF_STATUS
// 	tst	r18			; test for ENV_STOP
// 	breq	SKIP_REZ
// 					; mul signed:unsigned -> (a-b) * q
// 					; 16x8 into 16-bit
// 					; r19:r18 = r21:r20 (ah:al) * r22 (b)
// 	mulsu	r21, r22		; (signed)ah * b
// 	movw	r18, r0
// 	mul	r20, r22		; al * b
// 	add	r18, r1
// 	adc	r19, ZERO
// 	rol	r0			; r0.7 --> Cy
// 	brcc	NO_ROUND		; LSByte < $80, so don't round up
// 	inc	r18
// NO_ROUND:
// 	clc				; (a-b) * q * 4
// 	lsl	r18
// 	rol	r19
// OVERFLOW_3A:
// 	clc
// 	lsl	r18
// 	rol	r19
// OVERFLOW_3B:

// 	movw	z_L, r18		; q*(a-b) in z_H:z_L as signed
// 					; add both
// 					; both signed
// 					; ((in-a)+q*(a-b))
// 					; => HDAC:LDAC + z_H:z_L
// DCF_ADD:
// 	add	LDAC, z_L
// 	adc	HDAC, z_H

// 	brvc	OVERFLOW_4		; if overflow is clear
// 					; 0b1000.0000 0b0000.0001 -> min
// 					; 0b0111.1111 0b1111.1111 -> max
// 	ldi	LDAC, 0b11111111
// 	ldi	HDAC, 0b01111111
// OVERFLOW_4:
// 					; Result is a signed value in HDAC:LDAC
// 					; calc * f
// 					; ((in-a)+q*(a-b))*f
// 	lds	r20, LPF_I		; load lowpass 'F' value
// 	lds	r18, PATCH_SWITCH1
// 	sbrc	r18, SW_FILTER_MODE	; Check LP/HP switch.
// 	lds	r20, HPF_I		; Switch set, so load 'F' for HP
// 					; mul signed unsigned HDAC*F
// 					; 16x8 into 16-bit
// 					; r19:r18 = HDAC:LDAC (ah:al) * r20 (b)
// 	mulsu	HDAC, r20		; (signed)ah * b
// 	movw	r18, r0
// 	mul	LDAC, r20		; al * b
// 	add	r18, r1			; signed result in r19:r18
// 	adc	r19, ZERO
// 	rol	r0			; r0.7 --> Cy
// 	brcc	NO_ROUND2		; LSByte < $80, so don't round up
// 	inc	r18
// NO_ROUND2:
// 					; Add result to 'a'
// 					; a+=f*((in-a)+q*(a-b))
// 	add	a_L, r18
// 	adc	a_H, r19
// 	brvc	OVERFLOW_5		; if overflow is clear
// 					; 0b1000.0000 0b0000.0001 -> min
// 					; 0b0111.1111 0b1111.1111 -> max
// 	ldi	z_L, 0b11111111
// 	ldi	z_H, 0b01111111
// 	mov	a_L, z_L
// 	mov	a_H, z_H
// OVERFLOW_5:
// 					; calculated a+=f*((in-a)+q*(a-b)) as signed value and saved in a_H:a_L
// 					; calc 'b'
// 					; b += f * (a*0.5 - b)
// 	mov	z_H, a_H		; \
// 	mov	z_L, a_L		; / load 'a' as signed

// 	lds	temp, b_L		; \
// 	lds	temp2, b_H		; / load b as signed

// 	sub	z_L, temp		; \
// 	sbc	z_H, temp2		; / (a - b) signed

// 	brvc	OVERFLOW_6		; if overflow is clear
// 					; 0b1000.0000 0b0000.0001 -> min
// 					; 0b0111.1111 0b1111.1111 -> max
// 	ldi	z_L, 0b00000001
// 	ldi	z_H, 0b10000000
// OVERFLOW_6:

// 	lds	r20, LPF_I		; load lowpass 'F' value
// 	lds	r18, PATCH_SWITCH1
// 	sbrc	r18, SW_FILTER_MODE	; Check LP/HP switch.
// 	lds	r20, HPF_I		; Switch set to HP, so load 'F' for HP
// 					; mul signed unsigned (a-b) * F
// 					; 16x8 into 16-bit
// 					; r19:r18 = z_H:z_L (ah:al) * r20 (b)
// 	mulsu	z_H, r20		; (signed)ah * b
// 	movw	r18, r0
// 	mul	z_L, r20		; al * b
// 	add	r18, r1			; signed result in r19:r18
// 	adc	r19, ZERO

// 	add	temp,  r18		; \ add result to 'b' , signed
// 	adc	temp2, r19		; / b +=(a-b)*f

// 	brvc	OVERFLOW_7		; if overflow is clear
// 					; 0b1000.0000 0b0000.0001 -> min
// 					; 0b0111.1111 0b1111.1111 -> max
// 	ldi	temp,  0b11111111
// 	ldi	temp2, 0b01111111
// OVERFLOW_7:

// 	sts	b_L, temp		; \
// 	sts	b_H, temp2		; / save value of 'b'
// 	mov	LDAC, temp		; B now contains the filtered signal in HDAC:LDAC
// 	mov	HDAC, temp2		; output sample HDAC:LDAC = r17:r16

// does the code above manages signed input ?

// original code from meeblip
// https://github.com/MeeBlip/meeblip-synth/blob/master/meeblip-se-v2.asm

// can you make a separate module to calculate saturation, 
// and split each temp stage to a different variable ?

// the Saturation module is not instanciated in this new code

// in the previous code each temp stage had its own saturation calculation, 
// can you instantiate a saturation module for each temp stage ?

// the blocks have no reset signal

// it is usually better for reset signal to be active on low level

// The compiling returns the following warnirngs and errors: 
// %Warning-COMBDLY: meeblip_lpf.v:217:27: Delayed assignments (<=) in non-clocked (non flop or latch) block
//     : ... Suggest blocking assignments (=)
// 217 |             output_signal <= 0;
// |                           ^~
// ... Use "/* verilator lint_off COMBDLY */" and lint_on around source to disable this message.
// *** See the manual before disabling this,
// else you may end up with different sim results.
// %Warning-MULTIDRIVEN: meeblip_lpf.v:239:23: Signal has multiple driving blocks with different clocking: 'DigitallyControlledFilter.a'
// meeblip_lpf.v:294:13: ... Location of first driving block
// 294 |             a <= 0;
// |             ^
// meeblip_lpf.v:273:9: ... Location of other driving block
// 273 |         a <= a + cutoff * temp3;
// |         ^
// %Warning-MULTIDRIVEN: meeblip_lpf.v:236:30: Signal has multiple driving blocks with different clocking: 'audio_out'
// meeblip_lpf.v:298:13: ... Location of first driving block
// 298 |             audio_out <= 0;
// |             ^~~~~~~~~
// meeblip_lpf.v:279:9: ... Location of other driving block
// 279 |         audio_out <= temp1 + temp2;
// |         ^~~~~~~~~
// %Warning-MULTIDRIVEN: meeblip_lpf.v:240:23: Signal has multiple driving blocks with different clocking: 'DigitallyControlledFilter.b'
// meeblip_lpf.v:295:13: ... Location of first driving block
// 295 |             b <= 0;
// |             ^
// meeblip_lpf.v:276:9: ... Location of other driving block
// 276 |         b <= b + temp1;
// |         ^
// %Error-BLKANDNBLK: meeblip_lpf.v:241:23: Unsupported: Blocked and non-blocking assignments to same variable: 'DigitallyControlledFilter.q'
// 241 |     reg signed [15:0] q;
// |                       ^
// %Warning-MULTIDRIVEN: meeblip_lpf.v:242:23: Signal has multiple driving blocks with different clocking: 'DigitallyControlledFilter.scaled_resonance'
// meeblip_lpf.v:297:13: ... Location of first driving block
// 297 |             scaled_resonance <= 0;
// |             ^~~~~~~~~~~~~~~~
// meeblip_lpf.v:288:9: ... Location of other driving block
// 288 |         scaled_resonance <= resonance - (cutoff + Q_OFFSET);
// |         ^~~~~~~~~~~~~~~~

// each signal should be assigned by a single process

// to fix errors you can make a single process to initialize and update a,b,q,scaled_resonance and audio_out

// update of q and scaled_resonance is still in a separate process, merge their update with the main process

// I think the saturation module should be combinatorial

// the saturation module seems to saturate even though it should not

// looks the same as before to me. I suspect the issue are signed comparison not implemented correctly

// apply $signed to all assigments

// in the comparison of saturation, the $signed needs to be on both sides

// you can use the saturation module for audio_out too

// you should not assign a register to itself in a verilog non-combinatorial process

// why did you remove the saturation module applied to audio_out ?

module Saturation (
    input signed [15:0] input_signal,
    output reg signed [15:0] output_signal
);

    // Constants
    parameter [15:0] MAX_POS_VALUE = 16'h7FFF;
    parameter [15:0] MIN_NEG_VALUE = -16'h8000;

    always @* begin
        if ($signed(input_signal) > $signed(MAX_POS_VALUE))
            output_signal = $signed(MAX_POS_VALUE);
        else if ($signed(input_signal) < $signed(MIN_NEG_VALUE))
            output_signal = $signed(MIN_NEG_VALUE);
        else
            output_signal = input_signal;
    end

endmodule

module DigitallyControlledFilter (
    input clk,
    input signed [15:0] audio_in,
    input [15:0] cutoff,
    input [15:0] resonance,
    input reset_n,
    output reg signed [15:0] audio_out
);

    reg signed [15:0] a;
    reg signed [15:0] b;
    reg signed [15:0] q;
    reg signed [15:0] scaled_resonance;
    reg signed [15:0] temp1;
    reg signed [15:0] temp2;
    reg signed [15:0] temp3;
    // Temporary variables for calculations
    reg signed [15:0] temp_a;
    reg signed [15:0] temp_b;
    reg signed [15:0] temp_audio_out;

    // Constants
    parameter [15:0] ONE = 16'h7FFF;
    parameter [15:0] ZERO = 16'h0000;
    parameter [15:0] Q_OFFSET = 16'hXXXX; // Replace XXXX with the desired value.

    // Instantiate the Saturation module for intermediate signals
    Saturation sat_inst1(
        .input_signal(audio_in - a),
        .output_signal(temp1)
    );

    Saturation sat_inst2(
        .input_signal(temp1 + temp2),
        .output_signal(temp2)
    );

    // Instantiate the Saturation module for audio_out
    Saturation sat_inst3(
        .input_signal(temp2),
        .output_signal(audio_out)
    );

    always @(posedge clk) begin
        if (!reset_n) begin
            a <= $signed(0);
            b <= $signed(0);
            q <= $signed(0);
            scaled_resonance <= $signed(0);
            temp2 <= $signed(0);
            audio_out <= $signed(0);
        end else begin
            // Update q and scaled_resonance
            q <= $signed(resonance - (cutoff + Q_OFFSET));
            scaled_resonance <= $signed(resonance - (cutoff + Q_OFFSET));



            // Calculate a, b, and temp_audio_out
            temp_a = $signed(a + cutoff * temp3);
            temp_b = $signed(b + temp1);
            temp_audio_out = $signed(temp1 + temp2);

            // Update registers with temporary values
            a <= temp_a;
            b <= temp_b;
            temp2 <= temp_audio_out;
        end
    end

endmodule
