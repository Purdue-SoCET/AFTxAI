volatile int* const out_port = (volatile int*)0x1000;

int main() {
    int pass = 1;

    // Test unsigned comparisons
    unsigned int a = 0xFFFFFFFF; // -1 as unsigned is max
    unsigned int b = 0x00000001;
    
    if (a < b) pass = 0;   // BLTU should not take
    if (b > a) pass = 0;   // BLTU should not take
    if (!(a >= b)) pass = 0; // BGEU should take
    if (a <= b) pass = 0;  // BGEU should not take

    // Test signed comparisons
    int sa = -1;
    int sb = 1;
    
    if (sa >= sb) pass = 0; // BGE should not take
    if (!(sa < sb)) pass = 0; // BLT should take
    if (sb <= sa) pass = 0; // BLT should not take

    // Test AUIPC & LUI implicitly through globals/pointers if we had any,
    // but we can also test SLT/SLTI directly in C.
    int slt_res = (sa < sb) ? 1 : 0;
    if (slt_res != 1) pass = 0;

    int sltu_res = (a < b) ? 1 : 0;
    if (sltu_res != 0) pass = 0;

    // Test Shifts
    unsigned int v = 0x80000000;
    if ((v >> 31) != 1) pass = 0; // SRLI
    
    int sv = 0x80000000;
    if ((sv >> 31) != -1) pass = 0; // SRAI

    // Switch case (tests jump tables / JALR)
    int switch_val = 3;
    int switch_res = 0;
    switch(switch_val) {
        case 1: switch_res = 10; break;
        case 2: switch_res = 20; break;
        case 3: switch_res = 30; break;
        case 4: switch_res = 40; break;
        default: switch_res = 50; break;
    }
    if (switch_res != 30) pass = 0;

    // Recursion (tests JAL, stack, JALR)
    int multiply(int a, int b) {
        int res = 0;
        for(int i = 0; i < 32; i++) {
            if((b >> i) & 1) res += (a << i);
        }
        return res;
    }

    int fact(int n) {
        if (n <= 1) return 1;
        return multiply(n, fact(n - 1));
    }
    
    // We don't have multiply instruction, but gcc will use libgcc __mulsi3 which uses branches/add.
    if (fact(5) != 120) pass = 0;

    return pass ? 0x600D : 0xBAD0;
}
