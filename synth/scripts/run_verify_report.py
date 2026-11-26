import sys
import hashlib
import pya

gds_path = "/OpenROAD-flow-scripts/flow/platforms/sky130ram/sky130_sram_1rw1r_64x256_8/sky130_sram_1rw1r_64x256_8.gds"

# Compute SHA256
with open(gds_path, "rb") as f:
    sha = hashlib.sha256(f.read()).hexdigest()

print("="*60, flush=True)
print(" SRAM GDS SUPPLY SHORT VERIFICATION REPORT", flush=True)
print("="*60, flush=True)
print(f"Target Macro GDS: {gds_path}", flush=True)
print(f"GDS SHA-256:      {sha}", flush=True)
print("Upstream Issue:   OpenROAD-flow-scripts Issue #4752", flush=True)

layout = pya.Layout()
layout.read(gds_path)
top = layout.top_cell()
print(f"Top cell:         {top.name}", flush=True)
print(f"Layout DBU:       {layout.dbu} um", flush=True)

t_idx = layout.find_layer(70, 16)
d_idx = layout.find_layer(70, 20)

reg = pya.Region(top.shapes(d_idx))
print(f"Total met3 shapes in top cell: {reg.size()}", flush=True)

vdd_seeds = pya.Region()
gnd_seeds = pya.Region()

vdd_count = 0
gnd_count = 0
for s in top.shapes(t_idx).each():
    if s.is_text():
        txt = s.text.string.strip().lower()
        pt = pya.Point(s.text.x, s.text.y)
        box = pya.Box(pt.x-5, pt.y-5, pt.x+5, pt.y+5)
        if txt == "vdd":
            vdd_seeds += reg.interacting(pya.Region(box))
            vdd_count += 1
        elif txt in ["gnd", "vss"]:
            gnd_seeds += reg.interacting(pya.Region(box))
            gnd_count += 1

print(f"Text labels on met3: VDD={vdd_count}, GND={gnd_count}", flush=True)
print(f"Polygons touching VDD text: {vdd_seeds.size()}", flush=True)
print(f"Polygons touching GND text: {gnd_seeds.size()}", flush=True)

shorts = vdd_seeds & gnd_seeds
short_count = shorts.size()
short_area = shorts.area()

print("\n" + "-"*60, flush=True)
print(f"VERDICT: {'CRITICAL DEFECT CONFIRMED' if short_count > 0 else 'PASSED (CLEAN)'}", flush=True)
print(f"Total Short Polygons on met3: {short_count}", flush=True)
print(f"Total Shorted Area:           {short_area} dbu^2 ({short_area * 1e-6:.4f} um^2)", flush=True)
print("-"*60, flush=True)

if short_count > 0:
    print("\nSample short polygon bounding boxes (um):", flush=True)
    for i, p in enumerate(shorts.each()):
        if i < 8:
            b = p.bbox()
            print(f"  [{i+1}] ({b.left*0.001:.3f}, {b.bottom*0.001:.3f}) to ({b.right*0.001:.3f}, {b.top*0.001:.3f}) um", flush=True)
    print("\nELECTRICAL CONSEQUENCE: Complete hard short between VDD and GND.", flush=True)
    print("STATUS: Macro is physically UNQUALIFIED and FABRICATION BLOCKER.", flush=True)
    sys.exit(1)
else:
    print("No supply shorts detected.", flush=True)
    sys.exit(0)
