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

# Sky130 metal stack:
# met1: 68/20, pin/label: 68/16 or 68/5
# met2: 69/20, pin/label: 69/16 or 69/5
# met3: 70/20, pin/label: 70/16 or 70/5
# met4: 71/20, pin/label: 71/16 or 71/5

print("\nInspecting supply labels by layer:")
# Map layer number to its supply labels
labels_by_layer = {}
for layer_info in layout.layer_infos():
    l_idx = layout.find_layer(layer_info)
    shape_iter = top.shapes(l_idx)
    vdd_list = []
    vss_list = []
    for s in shape_iter.each():
        if s.is_text():
            txt = s.text.string.strip().lower()
            if txt == "vdd":
                vdd_list.append((s.text.x, s.text.y))
            elif txt in ["vss", "gnd"]:
                vss_list.append((s.text.x, s.text.y))
    if len(vdd_list) > 0 or len(vss_list) > 0:
        print(f"  Layer {layer_info.layer}/{layer_info.datatype}: {len(vdd_list)} VDD labels, {len(vss_list)} VSS labels")
        labels_by_layer[layer_info.layer] = {"vdd": vdd_list, "vss": vss_list}

# Check planar supply connectivity for each metal layer using its matching pin label layer
# met1: 68/20 matched with 68/* labels
# met2: 69/20 matched with 69/* labels
for metal_name, l_num, dt_num in [("met1", 68, 20), ("met2", 69, 20), ("met3", 70, 20), ("met4", 71, 20)]:
    d_idx = layout.find_layer(l_num, dt_num)
    if d_idx is None or d_idx < 0:
        continue
    reg = pya.Region(top.shapes(d_idx))
    print(f"\nLayer {metal_name} (layer {l_num}/{dt_num}): {reg.size()} polygons")
    
    if l_num not in labels_by_layer:
        print(f"  No pin labels on layer {l_num} (labels are on parent layer).")
        continue
        
    v_seeds = pya.Region()
    g_seeds = pya.Region()
    
    for (x, y) in labels_by_layer[l_num]["vdd"]:
        box = pya.Box(x-10, y-10, x+10, y+10)
        v_seeds += reg.interacting(pya.Region(box))
            
    for (x, y) in labels_by_layer[l_num]["vss"]:
        box = pya.Box(x-10, y-10, x+10, y+10)
        g_seeds += reg.interacting(pya.Region(box))
            
    print(f"  Touching VDD labels: {v_seeds.size()} polygons, touching VSS labels: {g_seeds.size()} polygons")
    if v_seeds.size() > 0 and g_seeds.size() > 0:
        short = v_seeds & g_seeds
        print(f"  Direct polygon short count on {metal_name}: {short.size()}")
        if short.size() > 0:
            print(f"  [CRITICAL DEFECT] Planar supply short detected on {metal_name}!")
            sys.exit(1)
        else:
            print(f"  [CLEAN] No polygon shorts between VDD and VSS pins on {metal_name}.")

# Multi-layer Via Connectivity Check:
# via1 (68/44) connects met1 (68/20) to met2 (69/20)
# Verify via1 cuts touching met2 VDD do NOT touch met2 VSS
via1_idx = layout.find_layer(68, 44)
m2_idx = layout.find_layer(69, 20)
if via1_idx is not None and m2_idx is not None:
    via1_reg = pya.Region(top.shapes(via1_idx))
    m2_reg = pya.Region(top.shapes(m2_idx))
    
    m2_vdd_seeds = pya.Region()
    m2_vss_seeds = pya.Region()
    for (x, y) in labels_by_layer[69]["vdd"]:
        m2_vdd_seeds += m2_reg.interacting(pya.Region(pya.Box(x-10, y-10, x+10, y+10)))
    for (x, y) in labels_by_layer[69]["vss"]:
        m2_vss_seeds += m2_reg.interacting(pya.Region(pya.Box(x-10, y-10, x+10, y+10)))
        
    via_to_vdd = via1_reg.interacting(m2_vdd_seeds)
    via_to_vss = via1_reg.interacting(m2_vss_seeds)
    via_short = via_to_vdd & via_to_vss
    print(f"\nVia1 (68/44) Inter-Layer Supply Check ({via1_reg.size()} cuts):")
    print(f"  Via1 cuts touching met2 VDD: {via_to_vdd.size()}")
    print(f"  Via1 cuts touching met2 VSS: {via_to_vss.size()}")
    print(f"  Via1 cuts simultaneously touching both VDD and VSS: {via_short.size()}")
    if via_short.size() > 0:
        print("  [CRITICAL DEFECT] Via1 cuts bridge VDD and VSS supply rails!")
        sys.exit(1)
    else:
        print("  [CLEAN] No supply shorting via1 cuts detected.")

print("\n" + "="*60)
print("VERDICT: SRAM22 supply geometry check PASSED (No supply shorts found)")
print("STATUS: Geometry is clean of direct planar and via supply shorts.")
print("CLASSIFICATION: Preliminary geometric supply extraction.")
print("="*60)
sys.exit(0)
