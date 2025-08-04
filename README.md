# UDPlease Synthesize

A minimalist, high-throughput, UDP packet processor for Zynq SoCs.

## I know
I know I haven't implemented the synthesise step yet so it's silly to call the project like this.
**But**, I will (eventually). And when I do, I'll probably have to use an open-source tool I've never touched before because my Vivado laptop is currently on vacation in Spain cosplaying as a home server for my parents (that's on me though). The point is, I fully expect to struggle with that whole part once I get to it, and the name feels appropriate in advance.

## What is this thing?

Do you want to process network packets at line rate, without the bloat of a full network stack in software?
Then you should probably go to [taxi](https://github.com/fpganinja/taxi). That's the real deal, with a whole suite of professional-grade networking cores.
However, if you want to see a super minimalist version of just the Ethernet/IP/UDP parsing part, built from the ground up with all the bugs and learning experiences left in, then this might be for you. This is less of a "reusable IP core" and more of a "learning diary written in Verilog."

## Where I am right now

The very basic functionality for all modules is done. For it only works DATA_WIDTH=8(bits) but I do plan on making it more versatile in the future. It is not the most robust design either (yet), since it doesn't handle runt packets (if `s_axis_tlast` arrives before the header is parsed, the cookie hits the fan). But for now:

  * It correctly uses an AXI-Stream interface.
  * It parses the corresponding header.
  * It streams the payload once the headers have been parsed and the conditions have been met.
  * It should handle backpressure, so it won't drop packets when things downstream get busy.

## How does it work?

All 3 moduels are built around a little state machine just like I learnt in uni:

1.  **S\_IDLE:** Sits around waiting for a packet to show up.
2.  **S\_PARSE\_HEADER:** Snaps up the 14-byte header.
3.  **S\_STREAM\_PAYLOAD:** Lets the rest of the packet flow through with zero delay.
4.  **S\_DROP:** This one only appears in the IP and UDP parsers, but it essentially just waits there until packet is done, then heads back to `S\_IDLE.`
5.  **S\_FINISH:** A special one-cycle state to make sure the end of the packet (`tlast`) is handled perfectly, even if the receiver is stalled.

## How to run this thing

This project uses [Verilator](https://verilator.org) for simulation. You'll need it, a C++ compiler, and a VCD viewer like `surfer` or `GTKWave`.

```bash
# To run compile, run the sim, and show the waves use
make run

# For cleaning up all the junk
make clean
```

## Future steps (in no particular order)

### In the oven right now
1. Synthesise, implementation and STA

### Fresh dough waiting in the fridge (might go bad)
2. Improve robustness by adding support for runt packets
3. Redesign to allow for more `DATA_WIDTH`

I am not sure when I will implement these last 2 functionalities. I have learnt a lot about these protocols as I developed this which was the main goal, and maybe I will start a new project on a related topic but with a more useful outcome.