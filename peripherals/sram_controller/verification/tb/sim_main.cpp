#include "Vtb_sram_controller.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    contextp->traceEverOn(true);
    
    Vtb_sram_controller* top = new Vtb_sram_controller{contextp};
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("dump.vcd");

    while (!contextp->gotFinish() && contextp->time() < 10000) {
        contextp->timeInc(1);
        top->eval();
        tfp->dump(contextp->time());
    }

    top->final();
    tfp->close();
    delete tfp;
    delete top;
    delete contextp;
    return 0;
}