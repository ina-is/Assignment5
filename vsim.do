vsim work.testbench
radix -hexadecimal
set UserTimerUnit ns
set RunLength 1000ns
view objects wave

# testbench
add wave /testbench/clk
add wave /testbench/reset
add wave /testbench/pcout
# IF
add wave /testbench/dut/imout
add wave /testbench/dut/pc4
add wave /testbench/dut/mpc
add wave /testbench/dut/ifout
# ID
add wave /testbench/dut/rstd
add wave /testbench/dut/rsel
add wave /testbench/dut/ra
add wave /testbench/dut/rb
add wave /testbench/dut/idout
# EX
add wave /testbench/dut/imm
add wave /testbench/dut/addr
add wave /testbench/dut/aluout
add wave /testbench/dut/exout
# MEM
add wave /testbench/dut/dma
add wave /testbench/dut/dmin
add wave /testbench/dut/dmout
add wave /testbench/dut/memout
# WB
add wave /testbench/dut/rc
add wave /testbench/dut/rset
add wave /testbench/dut/rfi/r1
add wave /testbench/dut/rfi/r2
add wave /testbench/dut/rfi/r3
add wave /testbench/dut/rfi/r29
add wave /testbench/dut/rfi/r30
add wave /testbench/dut/rfi/r31

run 2100 ns
wave zoomfull