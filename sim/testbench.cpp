#include <verilated.h>
#include <verilated_vcd_c.h>
#include <iostream>
#include <vector>
#include "Veth_parser.h"

void tick(Veth_parser* dut, VerilatedVcdC* trace, vluint64_t& sim_time) {
    dut->clk = 0;
    dut->eval();
    if (trace) trace->dump(sim_time++);

    dut->clk = 1;
    dut->eval();
    if (trace) trace->dump(sim_time++);
}

void send_byte(Veth_parser* dut, VerilatedVcdC* trace, vluint64_t& sim_time, uint8_t data, bool last) {

    while (dut->s_axis_tready == 0) {
        tick(dut, trace, sim_time);
    }

    dut->s_axis_tdata = data;
    dut->s_axis_tvalid = 1;
    dut->s_axis_tlast = last;

    tick(dut, trace, sim_time);

    dut->s_axis_tvalid = 0;
    dut->s_axis_tlast = 0;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Veth_parser* dut = new Veth_parser;

    Verilated::traceEverOn(true);
    VerilatedVcdC* trace = new VerilatedVcdC;
    dut->trace(trace, 99);
    trace->open("waveform.vcd");

    vluint64_t sim_time = 0;
    dut->rst = 1;
    dut->s_axis_tvalid = 0;
    dut->s_axis_tlast = 0;
    dut->m_axis_tready = 1;

    // --- Reset Sequence ---
    std::cout << "Starting reset..." << std::endl;
    tick(dut, trace, sim_time);
    tick(dut, trace, sim_time);
    dut->rst = 0;
    tick(dut, trace, sim_time);
    std::cout << "Reset complete." << std::endl;

    // --- Ethernet Frame Data ---

    std::vector<uint8_t> frame = {
        // Destination MAC
        0x11, 0x22, 0x33, 0x44, 0x55, 0x66,
        // Source MAC
        0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF,
        // EtherType (e.g., 0x0800 for IPv4)
        0x08, 0x00,
        // Payload (64 bytes total minimum frame size, including MACs/EtherType)
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F,
        0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B,
        // Frame Check Sequence (FCS) - dummy value for now
        0xDE, 0xAD, 0xBE, 0xEF
    };


    // --- Send the Frame ---
    std::cout << "Sending Ethernet frame..." << std::endl;
    for (size_t i = 0; i < frame.size(); ++i) {
        bool is_last = (i == frame.size() - 1);
        send_byte(dut, trace, sim_time, frame[i], is_last);
    }
    std::cout << "Frame sent." << std::endl;

    // --- Run for a few more cycles to observe idle state ---
    for (int i = 0; i < 20; ++i) {
        tick(dut, trace, sim_time);
    }

    // --- Cleanup ---
    trace->close();
    delete dut;
    delete trace;

    std::cout << "Simulation finished." << std::endl;
    return 0;
}