# Build a Monster Truck
https://www.roblox.com/games/121807425542434/Build-a-Monster-Truck

A Roblox Game about building a monster truck, crashing through obstacles to earn money, buying new blocks, and upgrading it to go as far as possible

<img width="860" height="345" alt="image" src="https://github.com/user-attachments/assets/e120d1e4-406c-4704-abb5-2bc81ee3938b" />

## NOTE:

For these hours, I only scripted some core mechanics of the game. The game is unfinished and some other features such as money or the shop won't work.
## NOTE: 
The code files are just the ones I wrote. They don't work outside of the game.
### What I did: 
- Vehicle Stats: Dynamically Calculates total fuel, strength, and engine power of the truck as it is being built, ignoring blocks that are not connected.
- Vehicle Setup: Attaches all the blocks together, adds suspension and motors to wheels, creates flipping and steering forces, and sends important information to the vehicle controller when the Drive button is pressed.
- Vehicle Controller: Allows the monster truck to smoothly drive, steer, and flip in the air. It calculates wheel speed, torque, wheel traction, flipping force, fuel usage, and distance.
- Obstacle Destruction: Detects collisions between the truck and obstacles ahead of time, and calculates the damage done to the obstacle and the truck. If the obstacle gets destroyed, destruction effects are shown, the truck is slowed down based on its strength, and the truck gets damaged. If the obstacle does not get destroyed, it completely stops the truck and damages it.
- Vehicle Destruction: The truck loses random blocks as it gets damaged by obstacles and falls apart when it is completely destroyed.
## Instructions
- Build a simple vehicle. The button on the right of the block inventory makes it show the next row. Make sure the truck has an engine, driver seat, and fuel
- Press the drive button
- Drive the truck into plants and rocks.
