#!/usr/bin/env python3
# clean_netlist.py
import sys

input_file = sys.argv[1]
output_file = sys.argv[2]

with open(input_file, 'r') as f:
    lines = f.readlines()

clean_lines = []
skip_idx = set()

# First pass: find all indices belonging to always/initial blocks or stray asserts/$write
i = 0
n = len(lines)
while i < n:
    line = lines[i]
    stripped = line.strip()
    
    if stripped.startswith('always @') or stripped.startswith('initial'):
        # Track until next module-level element
        skip_idx.add(i)
        i += 1
        while i < n:
            s = lines[i].strip()
            if s.startswith('sky130_') or s.startswith(r'\$_TBUF_') or s.startswith('assign') or s == 'endmodule':
                break
            if s.startswith('always @') or s.startswith('initial'):
                break
            skip_idx.add(i)
            i += 1
        continue
    elif '$write' in line or 'assert' in line or stripped == 'end':
        # Check if this line is part of a previous block
        if (i - 1) in skip_idx:
            skip_idx.add(i)
    i += 1

for idx, line in enumerate(lines):
    if idx not in skip_idx:
        clean_lines.append(line)

with open(output_file, 'w') as f:
    f.writelines(clean_lines)

print(f"Cleaned {input_file} -> {output_file} (filtered {len(skip_idx)} lines)")
