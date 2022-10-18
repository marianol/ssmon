# ssmon
 A Simple Serial MONitor for 6502 based SBCs


## Why?
This is an effort to get bact to doing 6502 assembler. It all started by watching [Ben Eater](https://eater.net/6502) in YT and wanting to dust off my EE past. So I begun my jurney building [YAsixfive02](https://github.com/marianol/YAsixfive02) a single board computer (SBC) based on the processor with options to expand. Now that is a reality in my bench so I needed some software for it, so here is my first take.

## How?
Before starting to modify existing things to run on my SBC architecture, looking at you [Microsoft Basic](https://github.com/mist64/msbasic), I needed to sharpen the saw and get working on 6502 assembler. 
My past goes to the C=64 days so I had my share of getting my hands dirty with a monitor and assembler. 

My approach to this is to write a simple interactive memory monitor.
- Functionality 
  - read, write to memory
  - jump (run) a program in memory
  - load a byte stream (program) to memory
- Design 
  - I/0 will be via serial. Why? is all I have for now :)
  - The simplicity and size in Wozmon for the Apple 1. Why? is the WoZ!!! 
  - Syntax is inspired in Supermon64, for the C=64. Why? because I like it. 

## Status
Work in Progress
