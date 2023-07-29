#!/usr/bin/env python3
#
from pueda.pyverilator import pyverilator_wrapper

def main_test(xen=True):
    # Load the Verilog module
    dut = pyverilator_wrapper('res_lpf_fix.v',
                            dump_en=True, # dump_fst=True,
                            dump_filename='res_lpf')

    # Set initial values for the parameters
    cutoff = 128 # 0x7000
    resonance = 0x7000
    # gain = 32
    nsamples = 1000
    input_peak = 32

    dut.sim.io.reset_n = 1
    dut.sim.clock.tick()

    # Simulation loop
    # for time_step in range(sim.time_step): # AttributeError: 'PyVerilator' object has no attribute 'finish'. Did you mean: 'finished'?
    for time_step in range(nsamples):
        # Update the parameter values for each time step
        dut.sim.io.cutoff = cutoff
        dut.sim.io.resonance = resonance
        # dut.sim.io.gain = gain

        # Generate the square wave input signal
        input_signal = input_peak if time_step % 100 < 50 else -input_peak

        # Apply the input signal to the Moog filter
        dut.sim.io.audio_in = input_signal

        # Evaluate the Verilog module
        dut.sim.clock.tick()
        
        # Read the output signal from the Moog filter
        # output_signal = dut.sim.io.audio_out

        # Perform any required analysis or verification here

        # Increment the parameter values for the next iteration
        # cutoff += 1
        # resonance += 1
        # gain += 1

    if True:
        if xen:
            dut.view_waves(savefname='res_lpf.gtkw')
        else:
            dut.view_waves(mode='vcdterm')

if __name__ == '__main__':
    main_test()