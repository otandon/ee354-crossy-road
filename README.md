# Crossy Road on FPGA

EE354 final project: a five-level Crossy Road game in Verilog for the Nexys A7-100T, displayed over VGA.

Team: Om Tandon (display and I/O), Ahmed Ataelfadeel (game logic).

- `DESIGN.md`: system design and specification
- `CLAUDE.md`: working rules for coding agents
- `skeleton/`: original EE354 VGA demo files (reference only)
- `src/`: synthesizable Verilog
- `proposal.pdf`, `class_requirements.pdf`: project proposal and course requirements

Simulate on the Mac with `scripts/sim.sh` (Icarus Verilog); build on the Vivado VM with `vivado -mode batch -source scripts/build.tcl`.
