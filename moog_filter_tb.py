#!/usr/bin/env python3
#
# generate a testbench for the moog filter above that injects a square wave, 
# while sweeping over cutoff, resonance and gain. the testbench shall be written for pyverilator

from pueda.pyverilator import pyverilator_wrapper

# Load the Verilog module
dut = pyverilator_wrapper('moog_filter.v',
                          dump_en=True, dump_fst=True,
                          dump_filename='moog_filter')

# Set initial values for the parameters
cutoff = 0
resonance = 0
gain = 0
nsamples = 1000

# Simulation loop
# for time_step in range(sim.time_step): # AttributeError: 'PyVerilator' object has no attribute 'finish'. Did you mean: 'finished'?
for time_step in range(nsamples):
    # Update the parameter values for each time step
    dut.sim.io.cutoff = cutoff
    dut.sim.io.resonance = resonance
    dut.sim.io.gain = gain

    # Generate the square wave input signal
    input_signal = 0x7FFF if time_step % 100 < 50 else 0x8000

    # Apply the input signal to the Moog filter
    dut.sim.io.audio_in = input_signal

    # Evaluate the Verilog module
    dut.sim.clock.tick()
    # sim.eval()

    # Read the output signal from the Moog filter
    output_signal = dut.sim.io.audio_out

    # Perform any required analysis or verification here

    # Increment the parameter values for the next iteration
    # cutoff += 1
    # resonance += 1
    # gain += 1

dut.view_waves(savefname='moog_filter.gtkw')