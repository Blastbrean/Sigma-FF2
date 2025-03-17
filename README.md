# Sigma-FF2
Of course, use at your own risk. Every update to the anticheat has a risk to open up the bypass to new detections.

The codebase is one-file, incomplete, very messy, and pretty rushed. It isn't anything important so I released it because I had fun with it!

Only exploits with `hookfunction`, `hookmetamethod`, and `firetouchinterest` can use this script. 

I didn't test any unknown exploits which might crash, have unintended behavior, or break. It has been tested on AWP + Wave. For best chance of it working as intended, please place this in your "autoexec' and make sure your exploit is faster than ReplicatedFirst.

The anticheat bypass has a failsafe in-case any new detections get added. But, this can easily be patched like when they moved around the shuffling routine, changed numbers, and AC strings in a recent update.

The bypass has some detection vector(s) that can be used in future updates due to laziness. Fixing them properly and properly maintaining it for future updates is up to the reader. However, a lot of it should be good.

Have fun :)

# Features
* Speed Hack
* Jump Power
* Boost On Height
* Reduce Catch Tackle
* Increase Catch Size
* Visualize Catch Zone
* Field Of View

# Script
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Blastbrean/Sigma-FF2/refs/heads/main/ff2_hider.lua"))()
```
