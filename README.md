🐍 Snake Game in 8086 Assembly

A classic Snake game built entirely in 8086 Assembly Language for EMU8086 using direct video memory manipulation and BIOS interrupts.

🎮 Features
Real-time snake movement
Continuous directional movement
Snake growth after eating apples
Random apple spawning
Screen wrapping mechanics
Optimized rendering
Only draws:
new head
erased tail
BIOS timer-based game loop
Direct access to VGA text mode memory (0B800h)
🖥️ Preview
5
⚙️ Technologies Used
8086 Assembly Language
BIOS Interrupts
VGA Text Mode
EMU8086
🧠 Concepts Used

This project demonstrates:

Direct video memory programming
Keyboard interrupt handling
BIOS timer interrupts
Real-time game loops
Collision detection
Dynamic arrays in assembly
Efficient rendering techniques
Game state management
📂 Project Structure
snake.asm
README.md
🚀 How It Works

The game stores the snake body using coordinate arrays:

snakeRow db 100 dup(0)
snakeCol db 100 dup(0)

Each frame:

1. Read keyboard input
2. Save old tail position
3. Shift snake body
4. Move head
5. Check borders
6. Check apple collision
7. Erase old tail
8. Draw new head

This avoids redrawing the entire snake every frame and makes the game much smoother.

🍎 Apple System

Apples spawn randomly using:

BIOS timer interrupt (INT 1Ah)
modulo division for screen bounds

When the snake eats an apple:

snake length increases
tail erase is skipped once
a new apple spawns randomly
🎯 Controls
Key	Action
↑	Move Up
↓	Move Down
←	Move Left
→	Move Right
🧱 Rendering Technique

The game uses direct writes to:

B800:0000

Each screen cell contains:

[ASCII Character][Color Attribute]

Example:

mov es:[di], ax
⏱️ Timing

The game uses BIOS timer ticks instead of delay loops:

INT 1Ah

This provides:

smoother movement
stable timing
lower CPU usage
📦 Requirements
EMU8086

Optional:

DOSBox
▶️ Running the Game
Open the project in EMU8086
Compile the .asm file
Run the program
📚 What I Learned

This project helped me understand:

Low-level graphics
Memory-mapped I/O
Real-time programming
Assembly optimization
Game architecture
Data structures in assembly
🔮 Future Improvements
Self-collision game over
Score system
Increasing speed
Main menu
Obstacles
Sound effects
Better random generation
📜 License

This project is open-source and available under the MIT License.

👨‍💻 Author

Mahmoud El Shoobary

Computer Engineering Student
Interested in:

Low-level programming
Cybersecurity
Reverse engineering
Game development
Systems programming
