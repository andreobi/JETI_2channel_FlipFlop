# JETI_2channel_FlipFlop
Lua App for Jeti RC. 
This App provides two independent selectable output controls (FD0..9).

The following logic is implemented:
- one or two inputs to SET the flipflop.
- one or two inputs to CLEAR the flipflop.
- if both states are true, clear will win.
- there is a selectable TIME (0.00 - 99.99 s) to deleay the CLEAR function.
- an input trigger could be the input level (LEVEL) or only the change from false to true (EDGE)
- two inputs could be combiened with an OR or an AND operation

Application examples

Simple delay:
- SET is always TRUE (log.MAX)
- CLEAR is the signal
- Time 0-99

Logic switch
- SET is always TRUE (log.MAX)
- CLEAR inputs are the signals
- Function: OR / AND 
- Time 0

...
