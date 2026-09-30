#3-Stage Pipeline
	- Create a functional Three-Stage RISC-V CPU which includes all relevant blocks
		- Include immediate generator, ALU, program counter, register file, control unit, branch resolution
		- Create submodules for seperate blocks
	- Stages are as follows
		- a standalone fetch stage pipeline
		- Decode and execute stages combined into an execute stage
		- Memory and writeback stages combined into a memory stage
	- There should be an individual forwarding and hazard unit 
	- The core should also account for branch prediction logic 
	- Include M, C, and B extensions of RISC-V
	- Data memory control
	- Include split L1 cache for instruction and data

