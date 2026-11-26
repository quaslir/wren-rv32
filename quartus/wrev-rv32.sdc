# Timing constraints for wren-rv32 (DE10-Lite, MAX 10 10M50DAF484C7G)
# Without this file Quartus assumes a 1 GHz clock and the fitter
# burns time chasing an unreachable target.

# 50 MHz board oscillator
create_clock -name clk -period 20.000 [get_ports clk]

derive_clock_uncertainty

# Asynchronous / human-speed I/O: do not time these paths
set_false_path -from [get_ports {rst btn sw_in[*]}]
set_false_path -to   [get_ports {led[*] hex[*] result[*]}]
