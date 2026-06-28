transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vlib riviera/xpm
vlib riviera/fifo_generator_v13_2_14
vlib riviera/xil_defaultlib

vmap xpm riviera/xpm
vmap fifo_generator_v13_2_14 riviera/fifo_generator_v13_2_14
vmap xil_defaultlib riviera/xil_defaultlib

vlog -work xpm  -incr "+incdir+../../../../../../2025.2/Vivado/data/rsb/busdef" -l xpm -l fifo_generator_v13_2_14 -l xil_defaultlib \
"C:/Sourish/2025.2/Vivado/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"C:/Sourish/2025.2/Vivado/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -93  -incr \
"C:/Sourish/2025.2/Vivado/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work fifo_generator_v13_2_14  -incr -v2k5 "+incdir+../../../../../../2025.2/Vivado/data/rsb/busdef" -l xpm -l fifo_generator_v13_2_14 -l xil_defaultlib \
"../../../ipstatic/simulation/fifo_generator_vlog_beh.v" \

vcom -work fifo_generator_v13_2_14 -93  -incr \
"../../../ipstatic/hdl/fifo_generator_v13_2_rfs.vhd" \

vlog -work fifo_generator_v13_2_14  -incr -v2k5 "+incdir+../../../../../../2025.2/Vivado/data/rsb/busdef" -l xpm -l fifo_generator_v13_2_14 -l xil_defaultlib \
"../../../ipstatic/hdl/fifo_generator_v13_2_rfs.v" \

vlog -work xil_defaultlib  -incr -v2k5 "+incdir+../../../../../../2025.2/Vivado/data/rsb/busdef" -l xpm -l fifo_generator_v13_2_14 -l xil_defaultlib \
"../../../../OFDM_FPGA.gen/sources_1/ip/fifo_generator_0_1/sim/fifo_generator_0.v" \

vlog -work xil_defaultlib \
"glbl.v"

