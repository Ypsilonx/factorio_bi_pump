# Fluid Bus

**Make your whole fluid main bus behave like one single tank.**

In Factorio 2.0 a long pipeline has to be split by pumps (a fluid segment may span at most 320 tiles).
Pumps push only one way and at most 1200/s, so a secondary source can't feed anything "upstream",
the bus overfills in front of a pump and runs dry behind it.

**Bus couplers** join all segments of BUS pipes into one network and keep their fill level even –
no matter how long the bus is or where the inputs and outputs are.

## Features
- **BUS variants of every pipe in the game** – vanilla and modded (Pyanodon, Bob's, …), with the same
  properties as the original. Recognize them by a spray-painted black **"B"**.
- **Bus coupler** (1×1, electric) – place it in the bus instead of a pump. It connects **only to BUS
  pipes**, so the "one tank" bus needs dedicated infrastructure.
- **Exact conservation** – fluid amount and temperature (steam) are preserved.
- **Circuit network** – the coupler outputs the **bus fill (%)** and the total fluid amount. Burn the
  surplus only above 90 %, start a backup source below 30 %.
- **Status in the coupler window** – network size and fill, no power, not connected, mixed fluids.
- **UPS friendly** – balancing is spread over ticks (whole network once per second by default).

## How to use
1. Research **Fluid bus** (after the pump technology).
2. Build the bus from BUS pipes – or upgrade your existing bus: build BUS pipes over the old ones
   (fluid is kept) or use the upgrade planner.
3. Replace the bus pumps with **bus couplers** and power them.
4. Connect inputs and outputs with ordinary pipes and a **pump right next to the bus**.

```
 before:  source ─══════[P]══════[P]══════[P]══════─   (flows one way only, max 1200/s)

 after:   input ─[pump]─┐                    ┌─[pump]─ factory
          ═══B══════════╧═══[C]═══B═══…═══[C]╧══════B═══
          [C] = bus coupler   B = BUS pipe   whole bus = one tank
```

## Settings (startup)
- **Bus coupler power** – default 50 kW.
- **Balancing interval** – default 60 ticks.

## Performance
Factorio 2.0.77, bus 30,000 tiles long with 1000 segments:

| Variant | ms/tick |
|---|---|
| vanilla pumps (1000) | 0.202 |
| bus couplers (1000, one network) | 0.526 |

## Compatibility
Tested (headless integration tests) with: vanilla, Space Age, Pyanodon's modpack, Bob's Logistics,
Pipe Tiers. BUS variants are generated from all pipes in the game, so other pipe mods should work too.

## Known limitations (v0.1)
- Temporary coupler graphics (tinted pipe) – a proper model comes in a later version.
- No flow limit per coupler yet (the bus is a perfect "one tank").
