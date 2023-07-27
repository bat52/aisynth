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

module DigitallyControlledFilter (
    input clk,
    input signed [15:0] audio_in,
    input [15:0] cutoff,
    input [15:0] resonance,
    output reg signed [15:0] audio_out
);

    reg signed [15:0] a;
    reg signed [15:0] b;
    reg signed [15:0] q;
    reg signed [15:0] scaled_resonance;
    reg signed [15:0] temp;

    // Constants
    parameter [15:0] ONE = 16'h7FFF;
    parameter [15:0] ZERO = 16'h0000;
    parameter [15:0] Q_OFFSET = 16'hXXXX; // Replace XXXX with the desired value.

    always @(posedge clk) begin
        // Calculate (in - a) and handle overflow
        temp = audio_in - a;
        if (temp > ONE) temp = ONE; // Overflow handling
        if (temp < -ONE) temp = -ONE;

        // Calculate q * (a - b) and handle overflow
        temp = q * (a - b);
        if (temp > ONE) temp = ONE; // Overflow handling
        if (temp < -ONE) temp = -ONE;

        // Calculate (in - a) + q * (a - b) and handle overflow
        temp = (audio_in - a) + q * (a - b);
        if (temp > ONE) temp = ONE; // Overflow handling
        if (temp < -ONE) temp = -ONE;

        // Update a
        a = a + cutoff * temp;

        // Calculate f * (a - b) and handle overflow
        temp = cutoff * (a - b);
        if (temp > ONE) temp = ONE; // Overflow handling
        if (temp < -ONE) temp = -ONE;

        // Update b
        b = b + temp;

        // Calculate f * ((in - a) + q * (a - b)) and handle overflow
        temp = cutoff * ((audio_in - a) + q * (a - b));
        if (temp > ONE) temp = ONE; // Overflow handling
        if (temp < -ONE) temp = -ONE;

        // Output the filtered audio
        audio_out = temp;
    end

    // Additional logic for calculating f and q
    always @(cutoff, resonance) begin
        q = resonance - (cutoff + Q_OFFSET);
    end

    always @(posedge clk) begin
        scaled_resonance = resonance - (cutoff + Q_OFFSET);
    end

    // Initialization
    initial begin
        a <= 16'h0000;
        b <= 16'h0000;
        q <= 16'h0000;
        scaled_resonance <= 16'h0000;
        audio_out <= 16'h0000;
    end

endmodule
