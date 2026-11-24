// Structural implementation of \$_TBUF_ using standard SKY130HD cells
// Both sky130_fd_sc_hd__inv_1 and sky130_fd_sc_hd__ebufn_1 are present in:
// - sky130_fd_sc_hd__tt_025C_1v80.lib
// - sky130_fd_sc_hd_merged.lef
//
// $_TBUF_ logic: when E=1, Y=A; when E=0, Y=Z (high-impedance).
// sky130_fd_sc_hd__ebufn_1: active-low enable TE_B. When TE_B=0, Z=A; when TE_B=1, Z=high-Z.
// Therefore TE_B = ~E (inverted enable).

module \$_TBUF_ (
    input  wire A,
    input  wire E,
    output wire Y
);
    wire enable_n;

    sky130_fd_sc_hd__inv_1 u_inv (
        .A(E),
        .Y(enable_n)
    );

    sky130_fd_sc_hd__ebufn_1 u_tri (
        .A(A),
        .TE_B(enable_n),
        .Z(Y)
    );
endmodule
