import sys

in_file = sys.argv[1]
out_file = sys.argv[2]

with open(in_file, 'r') as f:
    lines = f.readlines()

out_lines = []
current_addr = 0

def pad_to(addr):
    global current_addr
    while current_addr < addr:
        out_lines.append("00000000")
        current_addr += 4

for line in lines:
    line = line.strip()
    if not line: continue
    if line.startswith('@'):
        addr = int(line[1:], 16)
        pad_to(addr)
    else:
        bytes_list = line.split()
        for i in range(0, len(bytes_list), 4):
            if i + 3 < len(bytes_list):
                b0 = bytes_list[i]
                b1 = bytes_list[i+1]
                b2 = bytes_list[i+2]
                b3 = bytes_list[i+3]
                word = f"{b3}{b2}{b1}{b0}"
                out_lines.append(word)
                current_addr += 4
            else:
                # pad remaining bytes
                rem = bytes_list[i:]
                while len(rem) < 4:
                    rem.append("00")
                word = f"{rem[3]}{rem[2]}{rem[1]}{rem[0]}"
                out_lines.append(word)
                current_addr += 4

with open(out_file, 'w') as f:
    for out in out_lines:
        f.write(out + "\n")
