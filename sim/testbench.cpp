#include "Vtop_module.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <vector>
#include <cstdint>

vluint64_t sim_time = 0;
double sc_time_stamp() {
    return sim_time;
}

void tick(Vtop_module* dut, VerilatedVcdC* trace) {
    dut->clk = 0;
    dut->eval();
    if (trace) trace->dump(sim_time++);
    dut->clk = 1;
    dut->eval();
    if (trace) trace->dump(sim_time++);
}

void send_byte(Vtop_module* dut, VerilatedVcdC* trace, uint8_t data, bool last) {
    while (dut->s_axis_tready == 0) {
        tick(dut, trace);
    }
    
    dut->s_axis_tdata = data;
    dut->s_axis_tvalid = 1;
    dut->s_axis_tlast = last;

    tick(dut, trace);

    dut->s_axis_tvalid = 0;
    dut->s_axis_tlast = 0;
}

void send_frame(Vtop_module* dut, VerilatedVcdC* trace, const std::vector<uint8_t>& frame) {
    std::cout << "\n--- Sending NYSE OpenBook Frame (" << frame.size() << " bytes) ---" << std::endl;
    for (size_t i = 0; i < frame.size(); ++i) {
        bool is_last = (i == frame.size() - 1);
        send_byte(dut, trace, frame[i], is_last);
    }
    std::cout << "--- Frame Sent ---" << std::endl;
}


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vtop_module* dut = new Vtop_module;

    Verilated::traceEverOn(true);
    VerilatedVcdC* trace = new VerilatedVcdC;
    dut->trace(trace, 99);
    trace->open("waveform.vcd");

    // --- Initial State ---
    dut->rst = 1;
    dut->s_axis_tvalid = 0;
    dut->s_axis_tlast = 0;
    dut->m_axis_tready = 1;

    // --- Reset Sequence ---
    std::cout << "Starting reset..." << std::endl;
    tick(dut, trace);
    tick(dut, trace);
    dut->rst = 0;
    tick(dut, trace);
    std::cout << "Reset complete." << std::endl;

    // UDP Payload
    std::vector<uint8_t> udp_payload = {
        0x01, 0x01, 0xEA, 0x00,
        0x00, 0x00, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x27, 0x10,
        0x00, 0x00, 0x00, 0x64,
        0x00, 0x00, 0x00, 0x0A,
        0x01, 0x00, 0x00, 0x00
    };

    // UDP Header (8 bytes)
    std::vector<uint8_t> udp_header = {
        0xD3, 0x98,             // Source Port (e.g., 54168)
        0x61, 0xD4,             // Dest Port (e.g., 25044)
        0x00, (uint8_t)(8 + udp_payload.size()), // Length = UDP Hdr + Payload
        0xBE, 0xEF              // Checksum (dummy)
    };

    // IP Header (20 bytes)
    std::vector<uint8_t> ip_header = {
        0x45, 0x00,             // Version=4, IHL=5, ToS=0
        0x00, (uint8_t)(20 + 8 + udp_payload.size()), // Total Length = IP Hdr + UDP Hdr + Payload
        0x12, 0x34,             // Identification: 0x1234
        0x00, 0x00,             // Flags=0, Fragment Offset=0 (No Fragmentation!)
        0x40,                   // TTL = 64
        0x11,                   // Protocol = 17 (UDP)
        0xCA, 0xFE,             // Header Checksum (dummy)
        0xAC, 0x10, 0x0A, 0x01, // Source IP: 172.16.10.1
        0xE0, 0x00, 0x01, 0x30  // Dest IP: 224.0.1.48 (Example Multicast)
    };

    // Final Ethernet Frame
    std::vector<uint8_t> ethernet_frame;
    ethernet_frame.insert(ethernet_frame.end(), {0x01, 0x00, 0x5E, 0x00, 0x01, 0x30}); // Dest MAC
    ethernet_frame.insert(ethernet_frame.end(), {0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF}); // Src MAC
    ethernet_frame.insert(ethernet_frame.end(), {0x08, 0x00});                         // EtherType IPv4
    ethernet_frame.insert(ethernet_frame.end(), ip_header.begin(), ip_header.end());
    ethernet_frame.insert(ethernet_frame.end(), udp_header.begin(), udp_header.end());
    ethernet_frame.insert(ethernet_frame.end(), udp_payload.begin(), udp_payload.end());

    // --- Send the Frame ---
    send_frame(dut, trace, ethernet_frame);

    // --- Run for a few more cycles to observe idle state ---
    for (int i = 0; i < 20; ++i) {
        tick(dut, trace);
    }

    // --- Cleanup ---
    trace->close();
    delete dut;

    std::cout << "Simulation finished." << std::endl;
    return 0;
}