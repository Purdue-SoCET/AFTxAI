volatile int* const mem_flags = (volatile int*)0x1E00;
volatile int* const out_port = (volatile int*)0x1000;

int multiply(int a, int b) {
    int res = 0;
    for(int i = 0; i < 32; i++) {
        if((b >> i) & 1) {
            res += (a << i);
        }
    }
    return res;
}

int main() {
    mem_flags[0] = 0xA5A5A5A5; // marker 1
    
    int a = 15;
    int b = 23;
    int c = multiply(a, b); // 345
    
    mem_flags[1] = 0x5A5A5A5A; // marker 2
    
    // Bitwise ops
    volatile int x = 0x0F0F0F0F;
    volatile int y = 0x33333333;
    int and_res = x & y; // 0x03030303
    int or_res  = x | y; // 0x3F3F3F3F
    int xor_res = x ^ y; // 0x3C3C3C3C
    
    mem_flags[2] = and_res;
    mem_flags[3] = or_res;
    mem_flags[4] = xor_res;
    
    // Logical and arithmetic shifts
    volatile int neg = -1024; // 0xFFFFFC00
    int sra_res = neg >> 4;  // 0xFFFFFFC0  (-64)
    volatile unsigned int us = 0xFFFFFC00;
    int srl_res = us >> 4; // 0x0FFFFFC0
    
    mem_flags[5] = (int)sra_res;
    mem_flags[6] = (int)srl_res;
    
    if (c != 345) return 0x1111;
    if (mem_flags[0] != 0xA5A5A5A5) return 0x2222;
    if (mem_flags[1] != 0x5A5A5A5A) return 0x3333;
    if (mem_flags[2] != 0x03030303) return 0x4444;
    if (mem_flags[3] != 0x3F3F3F3F) return 0x5555;
    if (mem_flags[4] != 0x3C3C3C3C) return 0x6666;
    if (mem_flags[5] != -64) return 0x7777;
    if (mem_flags[6] != 0x0FFFFFC0) return 0x8888;
    
    return 0x600D;
}
