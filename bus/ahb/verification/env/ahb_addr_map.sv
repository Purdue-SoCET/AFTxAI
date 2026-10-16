`ifndef AHB_ADDR_MAP_SV
`define AHB_ADDR_MAP_SV

class ahb_addr_map extends uvm_object;
    `uvm_object_utils(ahb_addr_map)

    typedef struct {
        logic [31:0] base_addr;
        logic [31:0] end_addr;
        int sub_id;
    } region_t;

    region_t regions[$];

    function new(string name = "ahb_addr_map");
        super.new(name);
    endfunction

    function void add_region(logic [31:0] base, logic [31:0] end_a, int id);
        region_t r;
        r.base_addr = base;
        r.end_addr = end_a;
        r.sub_id = id;
        regions.push_back(r);
    endfunction

    function int decode(logic [31:0] addr);
        foreach (regions[i]) begin
            if (addr >= regions[i].base_addr && addr <= regions[i].end_addr) begin
                return regions[i].sub_id;
            end
        end
        return -1; // Unmapped
    endfunction

    function bit is_mapped(logic [31:0] addr);
        return (decode(addr) != -1);
    endfunction
endclass

`endif
