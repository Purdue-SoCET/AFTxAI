volatile int* const flags = (volatile int*)0x1E40;

int multiply(int a, int b) {
    int res = 0;
    for(int i = 0; i < 32; i++) {
        if((b >> i) & 1) res += (a << i);
    }
    return res;
}

int main() {
    int A[3][3] = { {1, 2, 3}, {4, 5, 6}, {7, 8, 9} };
    int B[3][3] = { {9, 8, 7}, {6, 5, 4}, {3, 2, 1} };
    int C[3][3] = { {0, 0, 0}, {0, 0, 0}, {0, 0, 0} };
    int expected[3][3] = { {30, 24, 18}, {84, 69, 54}, {138, 114, 90} };
    
    for(int i=0; i<3; i++) {
        for(int j=0; j<3; j++) {
            for(int k=0; k<3; k++) {
                C[i][j] += multiply(A[i][k], B[k][j]);
            }
        }
    }
    
    int pass = 1;
    for(int i=0; i<3; i++) {
        for(int j=0; j<3; j++) {
            if (C[i][j] != expected[i][j]) pass = 0;
            // Write to memory flags to ensure state matches
            flags[i*3 + j] = C[i][j];
        }
    }
    
    // Verify memory flags didn't get clobbered
    for(int i=0; i<3; i++) {
        for(int j=0; j<3; j++) {
            if (flags[i*3 + j] != expected[i][j]) pass = 0;
        }
    }
    
    return pass ? 0x600D : 0xBAD0;
}
