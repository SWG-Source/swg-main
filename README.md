# Star Wars Galaxies Source Code (C++) Build Tools

This is the main server code. Please feel free to contribute merge/pull requests, or fork the code to create variations. Please keep the license and credit information intact.

The majority of the work is thanks to Devcodex, with more fixes and optimizations provided by DarthArgus.

# src Repo:
# Main Branches
* master - stable, no debug flags
* testing - bleeding edge, works in progress, probably stable

# Works in progress
* testing-64 - fully 64 bit version thatbuilds but doesn't run, some typedefs and things are wrong

# Building

Only use the Debug and Release targets unless you want to work on 64 bit. For local testing, and non-live builds set MODE=Release or MODE=debug in build_linux.sh.

For production, user facing builds, set MODE=MINSIZEREL for profile built, heavily optimized versions of the binaries.

## Profiling and Using Profiles

To generate new profiles, build SWG with MODE=RELWITHDEBINFO. 

Add export LLVM_PROFILE_FILE="output-%p.profraw" to your startServer.sh file. 

WHILE THE SERVER IS RUNNING do a ps -a to get the pid's of each SWG executable. And take note of which ones are which.

After you cleanly exit (shutdown) the server, and ctrl+c the LoginServer, move each output-pid.profraw to a folder named for it's process.

Then, proceed to combine them into usable profiles for the compiler:

llvm-profdata merge -output=code.profdata output-*.profraw

Finally, then replace the profdata files with the updated versions, within the src/ tree.

See http://clang.llvm.org/docs/UsersManual.html#profiling-with-instrumentation for more information.

# Buy Darth A Caffinated Beverage

bitcoin:16e1QRRmnBmod3RLtdDMa5muKBGRXE3Kmh
