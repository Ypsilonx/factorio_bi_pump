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
- **Circuit network** – both values under the icon of the fluid in the bus: **red wire = amount**,
  **green wire = fill %**. Burn the surplus only above 90 %, start a backup source below 30 %.
- **Circuit control** – disable a coupler by a condition (like a pump); the *Bus balancing interval*
  signal sets how often its network is balanced.
- **Status in the coupler window** – network size and fill, no power, not connected, mixed fluids.
- **Status light** on the coupler: green = powered, yellow = low power, red = no power (glows at night).
- **UPS friendly** – balancing is spread over ticks (whole network once per second by default).

## How to use
1. Research **Fluid bus** (after advanced circuits in vanilla; in overhaul mods after the techs of the coupler ingredients).
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

## Settings
- **Bus coupler power** (startup) – default 50 kW.
- **Balancing interval** (map setting, changeable while playing) – default 5 ticks. Every N ticks a
  coupler network is balanced as a whole in one tick; afterwards all segments have the same fill %.

## Fast pumps (12,000/s and more)
There is no fixed flow cap. Between two balancing ticks the fill of segments drifts by about
2 × flow × interval / segment capacity – e.g. 12,000/s with interval 5: ±10 % for 100-pipe segments,
±3 % for 300-pipe segments. Lower the interval for short segments and very fast pumps.

## Performance
Factorio 2.0.77, balancing interval 5 ticks, script time after warm-up:

| Bus | average | worst tick |
|---|---|---|
| 110 couplers (one network) | 0.08 ms | 0.43 ms |
| 1000 couplers (one network, extreme) | ~0.6 ms | ~3.2 ms once per interval |

## Compatibility
Tested (headless integration tests) with: vanilla, Space Age, Pyanodon's modpack, Bob's Logistics,
Pipe Tiers. BUS variants are generated from all pipes in the game, so other pipe mods should work too.

## Known limitations (v0.1)
- No flow limit per coupler yet (the bus is a perfect "one tank").
