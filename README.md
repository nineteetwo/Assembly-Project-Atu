# MIPS Dino Run 🦖

https://github.com/user-attachments/assets/db859cd5-e293-4989-b0a5-a0e8b3ad8748


<div align="center">
  <img width="49%" src="https://github.com/user-attachments/assets/4f5b965d-2649-44d1-ac0f-9099623f48b2" alt="Gameplay 2" />
  <img width="49%" src="https://github.com/user-attachments/assets/8e968b91-8c2a-4a46-bbff-eeaf5d54c3a1" alt="Gameplay 3" />
</div>

<br />

A fully functional endless runner arcade game developed entirely in **MIPS Assembly Language**. This project demonstrates low-level programming concepts, memory manipulation, and real-time graphics rendering using the MARS Simulator.

![MIPS](https://img.shields.io/badge/Language-MIPS_Assembly-red)
![Simulator](https://img.shields.io/badge/Simulator-MARS_4.5-blue)
![Status](https://img.shields.io/badge/Status-Updated-brightgreen)

## 🎮 Game Overview
The player controls a dinosaur running through a scrolling landscape, avoiding obstacles to survive as long as possible.
* **Real-time Rendering:** Graphics are drawn directly to the memory address of the Bitmap Display.
* **Physics Engine:** Custom logic for gravity, jumping velocity, and ground collision.
* **Collision Detection:** Coordinate-based Bounding Box calculation to detect when the dino hits an obstacle.

## 🛠️ Prerequisites
To run this game, you need:
1.  **Java Runtime Environment (JRE)** installed on your machine.
2.  **MARS (MIPS Assembler and Runtime Simulator)**. You can download it [here](http://courses.missouristate.edu/KenVollmar/MARS/).

## ⚙️ Configuration & How to Run
Because this game uses the **Bitmap Display**, the simulator settings must be exact for the graphics to render correctly.

1.  Open the `.asm` file in MARS.
2.  Go to **Tools** -> **Bitmap Display**.
3.  Set the following values:
    * **Unit Width in Pixels:** `4`
    * **Unit Height in Pixels:** `4`
    * **Display Width in Pixels:** `1024`
    * **Display Height in Pixels:** `512`
    * **Base address for display:** `0x10040000 (heap)`
4.  Click **"Connect to MIPS"** in the Bitmap Display window.
5.  Go to **Tools** -> **Keyboard and Display MMIO Simulator** (required for input).
6.  Click **"Connect to MIPS"** in the MMIO window.
7.  Assemble (`F3`) and Run (`F5`).

## 🕹️ Controls
* **S**: Start the game / Restart after Game Over
* **Spacebar**: Jump
* **X**: Duck (crouch) — dodge flying enemies!
* **P**: Pause / Unpause the game

## 🆕 New Features (v2)
* **Ducking Mechanic:** Press `X` to crouch. Reduces hitbox height, lets you dodge pterodactyls!
* **Flying Enemies (Pterodactyl):** A 32×16 pterodactyl spawns periodically at mid-air height. Duck under it or jump over it.
* **High Score (File I/O):** Best score is saved to `highscore.dat` using MIPS file syscalls and persists between sessions.
* **Pause:** Press `P` at any time to freeze the game. Press `P` again to resume.

## 🧠 Technical Details
This project was originally developed as a final project for the **Computer Organization** course at Nile University. It was later forked and upgraded for the final project of the **Computer Organization** course at Adana Alparslan Turkes Science and Technology University. Key technical implementations include:
* **Memory Mapping:** Direct writing to the heap base address (`0x10040000`) to manipulate pixel colors.
* **Input Polling:** Checking the Memory Mapped IO address `0xffff0000` for keyboard interrupts.
* **Sprite Management:** Storing pixel data for the dinosaur, obstacles and pterodactyl in the `.data` segment.
* **File I/O:** MIPS syscalls 13/14/15/16 used to open, read, write and close `highscore.dat`.
* **State Machine:** Extended game loop with Paused and Ducking states managed via global variables in the data segment.

## 👨‍💻 Team 

* **Abdelrahman Alaa**
* **Amr Gaith**
* **Amro Mostafa**
* **Yara Alhussany**
* **Mohamed Medhat**

## New Additions
* **Faruk Işın (nineteetwo)**
