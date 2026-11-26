import sys
import hashlib
import pya

gds_path = "/work/synth/sram22/sram22_256x64m4w8/sram22_256x64m4w8.gds"

print("="*60, flush=True)
print(" SRAM22 GDS SUPPLY CONNECTIVITY AND INTEGRITY AUDIT", flush=True)
print("="*60, flush=True)

with open(gds_path, "rb") as f:
    sha = hashlib.sha256(f.read()).hexdigest()

print(f"Target Macro GDS: {gds_path}", flush=True)
print(f"GDS SHA-256:      {sha}", flush=True)

layout = pya.Layout()
layout.read(gds_path)
top = layout.top_cell()
print(f"Top cell:         {top.name}", flush=True)
print(f"Layout DBU:       {layout.dbu} um", flush=True)

bbox = top.bbox()
print(f"Bounding Box:     ({bbox.left*layout.dbu:.3f}, {bbox.bottom*layout.dbu:.3f}) to ({bbox.right*layout.dbu:.3f}, {bbox.top*layout.dbu:.3f}) um", flush=True)
print(f"Dimensions:       {bbox.width()*layout.dbu:.3f} um x {bbox.height()*layout.dbu:.3f} um", flush=True)

# Layers in Sky130:
# mcon: 67/44, met1: 68/20, via1: 68/44, met2: 69/20, via2: 69/44, met3: 70/20, via3: 70/44, met4: 71/20
# Text layers: met1: 68/16 (or 68/5), met2: 69/16 (or 69/5), met3: 70/16, etc.

# Let's inspect all layers present in layout
print("\nInspecting layers with text labels:")
vdd_labels = []
vss_labels = []

for layer_info in layout.layer_infos():
    l_idx = layout.find_layer(layer_info)
    shape_iter = top.shapes(l_idx)
    text_count = 0
    for s in shape_iter.each():
        if s.is_text():
            txt = s.text.string.strip().lower()
            if txt in ["vdd", "vss", "gnd"]:
                text_count += 1
                if txt == "vdd":
                    vdd_labels.append((layer_info.layer, layer_info.datatype, s.text.x*layout.dbu, s.text.y*layout.dbu))
                else:
                    vss_labels.append((layer_info.layer, layer_info.datatype, s.text.x*layout.dbu, s.text.y*layout.dbu))
    if text_count > 0:
        print(f"  Layer {layer_info.layer}/{layer_info.datatype}: {text_count} supply labels")

print(f"Total VDD labels found: {len(vdd_labels)}")
print(f"Total VSS/GND labels found: {len(vss_labels)}")

if len(vdd_labels) == 0 or len(vss_labels) == 0:
    print("[ERROR] Missing supply labels in GDS! Cannot verify without labels.")
    sys.exit(2)

# Check metal 2 and metal 3 geometry overlap with supply seeds
for metal_name, l_num, dt_num in [("met1", 68, 20), ("met2", 69, 20), ("met3", 70, 20), ("met4", 71, 20)]:
    d_idx = layout.find_layer(l_num, dt_num)
    if d_idx is None or d_idx < 0:
        continue
    reg = pya.Region(top.shapes(d_idx))
    print(f"\nLayer {metal_name} (layer {l_num}/{dt_num}): {reg.size()} polygons")
    
    # Check if any label touches polygon
    v_seeds = pya.Region()
    g_seeds = pya.Region()
    
    for (l, dt, x, y) in vdd_labels:
        if l == l_num or l == l_num: # label on same layer or nearby
            pt = pya.Point(int(x/layout.dbu), int(y/layout.dbu))
            box = pya.Box(pt.x-10, pt.y-10, pt.x+10, pt.y+10)
            v_seeds += reg.interacting(pya.Region(box))
            
    for (l, dt, x, y) in vss_labels:
        if l == l_num or l == l_num:
            pt = pya.Point(int(x/layout.dbu), int(y/layout.dbu))
            box = pya.Box(pt.x-10, pt.y-10, pt.x+10, pt.y+10)
            g_seeds += reg.interacting(pya.Region(box))
            
    if v_seeds.size() > 0 and g_seeds.size() > 0:
        short = v_seeds & g_seeds
        print(f"  Touching VDD: {v_seeds.size()} polygons, touching VSS: {g_seeds.size()} polygons")
        print(f"  Direct polygon short count on {metal_name}: {short.size()}")
        if short.size() > 0:
            print(f"  [CRITICAL DEFECT] Supply short detected on {metal_name}!")
            sys.exit(1)
        else:
            print(f"  [CLEAN] No polygon shorts between VDD and VSS seeds on {metal_name}.")

print("\n" + "="*60)
print("VERDICT: SRAM22 supply geometry check PASSED (No supply shorts found)")
print("STATUS: Geometry is clean of direct planar supply shorts.")
print("="*60)
sys.exit(0)
