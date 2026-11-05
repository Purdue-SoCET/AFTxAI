#!/usr/bin/env python3

import yaml
import sys
import os

def to_hex(val):
    if isinstance(val, str):
        val = val.replace("_", "")
        return f"0x{int(val, 16):08X}"
    return f"0x{val:08X}"

def main():
    if len(sys.argv) < 4:
        print("Usage: gen_map.py <yaml_file> <out_sv> <out_h>")
        sys.exit(1)

    yaml_file = sys.argv[1]
    sv_file = sys.argv[2]
    h_file = sys.argv[3]

    with open(yaml_file, 'r') as f:
        data = yaml.safe_load(f)

    # Generate SV Package
    with open(sv_file, 'w') as f:
        f.write("`ifndef AFT_MAP_PKG_SV\n")
        f.write("`define AFT_MAP_PKG_SV\n\n")
        f.write("package aft_map_pkg;\n\n")

        for bus, regions in data.get('regions', {}).items():
            f.write(f"    // {bus.upper()} Regions\n")
            for name, props in regions.items():
                base_str = to_hex(props['base'])
                words = props['words']
                upper_name = name.upper()
                f.write(f"    localparam logic [31:0] {upper_name}_BASE = 32'h{base_str[2:]};\n")
                f.write(f"    localparam int {upper_name}_WORDS = {words};\n")
            f.write("\n")

        f.write("    // Interrupts\n")
        for name, irq in data.get('interrupts', {}).items():
            f.write(f"    localparam int IRQ_{name.upper()} = {irq};\n")

        f.write("\nendpackage\n\n")
        f.write("`endif // AFT_MAP_PKG_SV\n")

    # Generate C Header
    with open(h_file, 'w') as f:
        f.write("#ifndef AFT_MAP_H\n")
        f.write("#define AFT_MAP_H\n\n")

        for bus, regions in data.get('regions', {}).items():
            f.write(f"// {bus.upper()} Regions\n")
            for name, props in regions.items():
                base_str = to_hex(props['base'])
                words = props['words']
                upper_name = name.upper()
                f.write(f"#define {upper_name}_BASE {base_str}\n")
                f.write(f"#define {upper_name}_WORDS {words}\n")
            f.write("\n")

        f.write("// Interrupts\n")
        for name, irq in data.get('interrupts', {}).items():
            f.write(f"#define IRQ_{name.upper()} {irq}\n")

        f.write("\n#endif // AFT_MAP_H\n")

if __name__ == '__main__':
    main()
