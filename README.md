# BITBLOOM - 16-bit Assembly Balloon Game

A fully playable balloon-popping arcade game built entirely in x86 Assembly language for DOS. 

This project was developed for my Computer Organization and Assembly Language (COAL) course. It demonstrates low-level hardware interfacing, direct memory access, and custom interrupt handling to create a real-time game loop without relying on modern high-level libraries.

## 🕹️ Features
* **Custom Interrupt Handlers:** Overrides the hardware keyboard interrupt (Int 09h) for responsive, non-blocking input, and the timer interrupt (Int 1Ch) for frame-independent blinking and UI updates.
* **Direct VGA Rendering:** Bypasses BIOS drawing routines by directly writing pixel data to the VGA video memory segment (`0xA000`) in Mode 13h (320x200, 256 colors).
* **Hardware Sound:** Generates dynamic "popping" sound effects by directly programming the PC Speaker and Programmable Interval Timer (PIT) ports.
* **File I/O:** Utilizes DOS interrupts to dynamically load binary graphic assets and color palettes from an external `IMAGE.DAT` file.
* **Custom Text Rendering:** Includes a hand-coded 8x8 bitmap font system to render strings, scores, and timers directly to the screen.

## ⚙️ Tech Stack
* **Language:** x86 Assembly (16-bit)
* **Environment:** DOS / DOSBox
* **Assembler:** NASM

## 🚀 How to Run Locally
To play this game, you will need an x86 emulator like DOSBox.

1. Clone this repository.
2. Ensure `IMAGE.DAT` is in the same directory as the executable.
3. Assemble the code using NASM: `nasm -f bin main.asm -o game.com`
4. Mount the directory in DOSBox and run `game.com`.
