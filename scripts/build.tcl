# Non-project Vivado build for crossy_top on the Nexys A7-100T.
#
#   vivado -mode batch -source scripts/build.tcl
#
# Run from the repository root. Reports, checkpoints and the bitstream go to
# build/. Vivado itself writes vivado.log / vivado.jou and .Xil/ into the
# current directory (git-ignored); to keep those in build/ too, run
#   vivado -mode batch -source scripts/build.tcl -log build/vivado.log -journal build/vivado.jou

set root [file normalize [file join [file dirname [info script]] ..]]
set src  [file join $root src]
set out  [file join $root build]
set part xc7a100tcsg324-1
file mkdir $out

# ------------------------------------------------------------------ sources
foreach f [lsort [glob -directory $src *.v]] {
  read_verilog $f
}
read_xdc [file join $root constr crossy.xdc]

# ------------------------------------------------------------------ synthesis
synth_design -top crossy_top -part $part -include_dirs $src
write_checkpoint -force [file join $out post_synth.dcp]
report_utilization -file [file join $out utilization_synth.rpt]

# ------------------------------------------------------------------ implementation
opt_design
place_design
route_design
write_checkpoint -force [file join $out post_route.dcp]

report_timing_summary -file [file join $out timing_summary.rpt]
report_utilization    -file [file join $out utilization.rpt]
report_methodology    -file [file join $out methodology.rpt]

# ------------------------------------------------------------------ quick pass/fail summary
# Informational only; the reports above are the authority.
set latches [llength [get_cells -hierarchical -quiet -filter {REF_NAME =~ LD*}]]
set wns "n/a"
if {[catch {set wns [get_property SLACK [get_timing_paths -setup -max_paths 1 -nworst 1]]}]} {
  set wns "n/a"
}
puts "================================================================"
puts "BUILD SUMMARY  latches=$latches  WNS=$wns ns"
puts "  pass needs: latches=0, WNS >= 0, and no 'inferring latch' or"
puts "  multi-driven messages in the synthesis log."
puts "================================================================"

# ------------------------------------------------------------------ bitstream
write_bitstream -force [file join $out crossy_top.bit]
