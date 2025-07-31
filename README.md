# UDPlease Synthesize

A minimalist, high-throughput, UDP packet processor for Zynq SoCs.

## I know
I know I haven't implemented the synthesise step yet so it's sily to call the project like this.
**But**, I will (eventually). And when I do, I'll probably have to use an open-source tool I've never touched before because my Vivado laptop is currently on vacation in Spain cosplaying as a home server for my parents (that's on me though). The point is, I fully expect to struggle with that whole part once I get to it, and the name feels appropriate in advance.

## What is this thing?

Do you want to process network packets at line rate, without the bloat of a full network stack in software?
Then you should probably go to [taxi](https://github.com/fpganinja/taxi). That's the real deal, with a whole suite of professional-grade networking cores..
However, if you want to see a super minimalist version of just the Ethernet/IP/UDP parsing part, built from the ground up with all the bugs and learning experiences left in, then this might be for you. This is less of a "reusable IP core" and more of a "learning diary written in Verilog."

## Where I am right now

The `eth_parser` module is fresh out of the oven, so far it only works DATA_WIDTH=8(bits) but I do plan on making it more versatile in the soon future.

  * It correctly uses an AXI-Stream interface.
  * It sniff sniffs the first 14 bytes of an Ethernet header.
  * It figures out if the packet is for us (`TARGET_MAC_ADDR`) or for everyone (`BROADCAST_MAC_ADDR`).
  * It should handle backpressure, so it won't drop packets when things downstream get busy.

## How does it work?

It's all built around a little four-state machine just like I learnt in uni:

1.  **S\_IDLE:** Sits around waiting for a packet to show up.
2.  **S\_PARSE\_HEADER:** Snaps up the 14-byte header.
3.  **S\_STREAM\_PAYLOAD:** Lets the rest of the packet flow through with zero delay.
4.  **S\_FINISH:** A special one-cycle state to make sure the end of the packet (`tlast`) is handled perfectly, even if the receiver is stalled.

## How to run this thing

This project uses [Verilator](https://verilator.org) for simulation. You'll need it, a C++ compiler, and a VCD viewer like `surfer` or `GTKWave`.

```bash
# To run compile, run the sim, and show the waves use
make run

# For cleaning up all the junk
make clean
```

## Future

### In the oven right now

1.  `ip_parser` module.

### Fresh dough waiting in the fridge

2.  `udp_parser` module.
3.  Actually synthesize the thingy.