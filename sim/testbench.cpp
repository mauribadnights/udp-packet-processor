#include "Vtop_module.h"
#include "verilated.h"
#include "verilated_vcd_c.h" // For waveform generation
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
    std::cout << "\n--- Sending New Frame (" << frame.size() << " bytes) ---" << std::endl;
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
    dut->m_axis_tready = 1; // Assume downstream is always ready

    // --- Reset Sequence ---
    std::cout << "Starting reset..." << std::endl;
    tick(dut, trace);
    tick(dut, trace);
    dut->rst = 0;
    tick(dut, trace);
    std::cout << "Reset complete." << std::endl;

    // --- Test Data Construction ---
    // We will fragment a larger UDP packet.
    // Let's create two IP fragments.

    // --- Fragment 1 ---
    std::vector<uint8_t> ip_fragment_1 = {
        // --- IP Header (20 bytes) ---
        0x45, 0x00,             // Version=4, IHL=5, ToS=0
        0x00, 0x24,             // Total Length = 36 bytes (20 IP Hdr + 16 Payload)
        0xAB, 0xCD,             // Identification: 0xABCD (Must be same for all fragments)
        0x20, 0x00,             // Flags=0b001 (More Fragments), Fragment Offset=0
        0x40,                   // TTL = 64
        0x11,                   // Protocol = 17 (UDP)
        0xBE, 0xEF,             // Header Checksum (dummy value)
        0xC0, 0xA8, 0x01, 0x0A, // Source IP: 192.168.1.10
        0xC0, 0xA8, 0x01, 0x14, // Destination IP: 192.168.1.20
        // --- IP Payload (16 bytes) ---
        // This would be the UDP header and start of UDP payload
        'T', 'h', 'i', 's', ' ', 'i', 's', ' ', 
        't', 'h', 'e', ' ', 'f', 'i', 'r', 's'
    };

    // --- Fragment 2 ---
    std::vector<uint8_t> ip_fragment_2 = {
        // --- IP Header (20 bytes) ---
        0x45, 0x00,             // Version=4, IHL=5, ToS=0
        0x00, 0x1B,             // Total Length = 27 bytes (20 IP Hdr + 7 Payload)
        0xAB, 0xCD,             // Identification: 0xABCD (Same as Fragment 1)
        0x00, 0x02,             // Flags=0b000 (Last Fragment), Fragment Offset=2 (16 bytes / 8)
        0x40,                   // TTL = 64
        0x11,                   // Protocol = 17 (UDP)
        0xCA, 0xFE,             // Header Checksum (dummy value)
        0xC0, 0xA8, 0x01, 0x0A, // Source IP: 192.168.1.10
        0xC0, 0xA8, 0x01, 0x14, // Destination IP: 192.168.1.20
        // --- IP Payload (7 bytes) ---
        't', ' ', 'p', 'a', 'c', 'k', 't'
    };

    // --- Fragment 3 ---
    std::vector<uint8_t> ip_fragment_3 = {
        // --- IP Header (20 bytes) ---
        0x45, 0x00,             // Version=4, IHL=5, ToS=0
        0x00, 0x23,             // Total Length = 35 bytes (20 IP Hdr + 15 Payload)
        0xAB, 0xCE,             // Identification: 0xABCD (Must be same for all fragments)
        0x20, 0x00,             // Flags=0b001 (More Fragments), Fragment Offset=0
        0x40,                   // TTL = 64
        0x06,                   // Protocol = 6 (TCP)
        0xBE, 0xEF,             // Header Checksum (dummy value)
        0xC0, 0xA8, 0x01, 0x0A, // Source IP: 192.168.1.10
        0xC0, 0xA8, 0x01, 0x14, // Destination IP: 192.168.1.20
        // --- IP Payload (16 bytes) ---
        // This would be the UDP header and start of UDP payload
        'T', 'h', 'i', 's', ' ', 'i', 's', ' ', 
        'N', 'O', 'T', ' ', 'U', 'D', 'P'
    };

    // --- Encapsulate fragments into Ethernet frames ---
    std::vector<uint8_t> ethernet_frame_1;
    ethernet_frame_1.insert(ethernet_frame_1.end(), {0x11, 0x22, 0x33, 0x44, 0x55, 0x66}); // Dest MAC
    ethernet_frame_1.insert(ethernet_frame_1.end(), {0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF}); // Src MAC
    ethernet_frame_1.insert(ethernet_frame_1.end(), {0x08, 0x00}); // EtherType IPv4
    ethernet_frame_1.insert(ethernet_frame_1.end(), ip_fragment_1.begin(), ip_fragment_1.end()); // IP Fragment 1

    std::vector<uint8_t> ethernet_frame_2;
    ethernet_frame_2.insert(ethernet_frame_2.end(), {0x11, 0x22, 0x33, 0x44, 0x55, 0x66}); // Dest MAC
    ethernet_frame_2.insert(ethernet_frame_2.end(), {0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF}); // Src MAC
    ethernet_frame_2.insert(ethernet_frame_2.end(), {0x08, 0x00}); // EtherType IPv4
    ethernet_frame_2.insert(ethernet_frame_2.end(), ip_fragment_2.begin(), ip_fragment_2.end()); // IP Fragment 2

    std::vector<uint8_t> ethernet_frame_3;
    ethernet_frame_3.insert(ethernet_frame_3.end(), {0x11, 0x22, 0x33, 0x44, 0x55, 0x66}); // Dest MAC
    ethernet_frame_3.insert(ethernet_frame_3.end(), {0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF}); // Src MAC
    ethernet_frame_3.insert(ethernet_frame_3.end(), {0x08, 0x00}); // EtherType IPv4
    ethernet_frame_3.insert(ethernet_frame_3.end(), ip_fragment_3.begin(), ip_fragment_3.end()); // IP Fragment 3

    // --- Send the Frames ---
    send_frame(dut, trace, ethernet_frame_1);
    
    // Inter-packet gap
    for (int i=0; i<10; ++i) tick(dut, trace);

    send_frame(dut, trace, ethernet_frame_2);

    // Inter-packet gap
    for (int i=0; i<10; ++i) tick(dut, trace);

    send_frame(dut, trace, ethernet_frame_3);

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