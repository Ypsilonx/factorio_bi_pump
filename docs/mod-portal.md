# Fluid Bus

**Make your whole fluid main bus behave like one single tank.**

In Factorio 2.x a long pipeline has to be split by pumps (a fluid segment may span at most 320 tiles).
Pumps push only one way and at most 1200/s, so a secondary source can't feed anything "upstream",
the bus overfills in front of a pump and runs dry behind it.

**Bus couplers** join all segments of BUS pipes into one network and keep their fill level even –
no matter how long the bus is or where the inputs and outputs are.

## Features
- **BUS variants of every pipe in the game** – vanilla and modded (Pyanodon, Bob's, …), with the same
  properties as the original. Recognize them by a spray-painted black **"B"**.
- **Bus coupler** (1×1, electric) – place it in the bus instead of a pump. It connects **only to BUS
  pipes**, so the "one tank" bus needs dedicated infrastructure. BUS pipes connect only to BUS pipes,
  couplers and **pumps** – a pump is the gateway between the bus and ordinary pipes.
- **Exact conservation** – fluid amount and temperature (steam) are preserved.
- **Circuit network** – like any pipe in Factorio 2.1, a **BUS pipe reads the pipeline contents** by wire
  (amount in its segment). The couplers keep every segment at the same fill, so one reading pipe tells
  you the state of the whole bus. Burn the surplus only above 90 %, start a backup source below 30 %.
  The coupler itself sends nothing.
- **Priority / overflow** – wire a BUS pipe in front of the coupler to it and set the condition to half
  of that segment's capacity (50 pipes × 100 = 5000 → "[fluid] > 2500"): the sides are joined only
  when the bus in front is more than half full.
- **Circuit control** – disable a coupler by a condition (like a pump); the *Bus balancing interval*
  signal sets how often its network is balanced.
- **Own coupler window** (laid out like the inserter window) – status, preview, network size, fill and
  amount, electricity, and a *Circuit connection* panel with just Enable/Disable and the condition.
- **Status light** on the coupler: green = powered, yellow = low power, red = no power (glows at night).
- **UPS friendly** – networks are balanced every 5 ticks by default (map setting), large buses are
  spread over ticks; see Performance below.

## How to use
1. Research **Fluid bus** (after advanced circuits in vanilla; in overhaul mods after the techs of the coupler ingredients).
2. Build the bus from BUS pipes – or upgrade your existing bus: build BUS pipes over the old ones
   (fluid is kept) or use the upgrade planner.
3. Replace the bus pumps with **bus couplers** and power them.
4. Connect inputs and outputs through a **pump attached directly to a BUS pipe** (ordinary pipes and
   tanks do not connect to BUS pipes).

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
Factorio 2.1.23, balancing interval 5 ticks, script time after warm-up (bus filling up):

| Bus | average | worst tick |
|---|---|---|
| 110 couplers (one network) | 0.10 ms | 0.61 ms |
| 1000 couplers (one network, extreme) | ~0.8 ms | ~5.3 ms once per interval |
| 1000 couplers (19 networks of 52 segments) | 0.60 ms | 2.2 ms |

## Upgrading from 0.2
Since 0.3.0 (Factorio 2.1) the coupler no longer sends the fill % signal – pipes read their contents
natively now. Move wires from the coupler to a BUS pipe ("Read pipeline contents") and convert conditions
from % to amounts (segment capacity = 100 per pipe). A coupler condition like "[fluid] > 50" without a wire
stops working – wire a BUS pipe to the coupler.

## Upgrading from 0.1
Since 0.2.0 BUS pipes no longer connect to ordinary pipes, tanks or machines. In an existing save such
connections are cut after the update – put a **pump** between the bus and the ordinary pipe.
The coupler now sends only the fill % on the green wire; the red-wire amount signal is gone.

## Compatibility
Tested on Factorio 2.1 (headless integration tests) with: vanilla, Space Age, Pyanodon's modpack 3.1,
Bob's Logistics 3.0. Pipe Tiers has no Factorio 2.1 release yet – Fluid Bus already loads after it, so its
pipe extents carry over once it is updated. BUS variants are generated from all pipes in the game, so
other pipe mods should work too.

## Known limitations
- With an overflow condition the coupler pulses: after joining, the fill may drop below the threshold
  and the coupler switches off again. Condition changes are picked up within 1 second.
- Signals on one circuit network add up: two BUS pipes reading the same fluid on one wire report double.
  Use one reading pipe per circuit network.
- Steam of different temperatures in one network is mixed (weighted average) – keep 165 °C and
  500 °C steam on separate buses.
- Two couplers directly next to each other do not connect – put at least one BUS pipe between them.
- A pump directly next to a coupler does not count as that coupler's side (status "Not connected to a BUS
  pipe") – put at least one BUS pipe between the coupler and the pump.

## Support
Enjoying the mod? You can support its development:

[![Buy Me a Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/ypsilonx)
