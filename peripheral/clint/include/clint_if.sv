interface clint_if #(
    parameter NUM_HARTS=1
) ();
    logic [NUM_HARTS-1:0] timer_int, clear_timer_int, soft_int, clear_soft_int;
    logic [63:0] mtime;

    modport clint (
        output timer_int, clear_timer_int, soft_int, clear_soft_int, mtime
    );

    modport top (
        input timer_int, clear_timer_int, soft_int, clear_soft_int, mtime
    );
endinterface
