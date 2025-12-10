Programming Fundamentals 1
---------------------------

Solar System Simulator - Milestone
Group Members: Bolcau Leonardo Gabriel and Pruneanu Andrei 

---------------------------

1. Implemented Features:
The current state of the project includes:

- Celestial Body Structure: defined structs for Sun and 8 planets (radius, orbit, color, speed).

- Orbital Mechanics: implemented the math to calculate (x, y) coordinates based on polar coordinates (angle and radius), allowing planets to orbit at different speeds relative to the Sun.

- Graphical Assets: added bitmap images for planets and visual orbit paths (rings) for scale.

- Interactive Zoom: capability to zoom in and out using keyboard controls to view different scales of the system.

- Mouse Interaction & Hover Effects: implemented a logic to track mouse coordinates; planets now "light up" (display a glowing ring) when the user hovers the cursor over them.

- Camera Tracking System (Lock-on): implemented a "Click-to-Follow" feature. Users can click on any planet to lock the camera view onto it, keeping it fixed at the center of the screen while the universe moves relative to it. Clicking the Sun resets the view.

2. New features added: 

- Star Field: procedurally generated background stars

- Mission System (Probe Launching): implemented a logic to launch probes from a departure planet to a target planet, calculating the trajectory needed to intercept the moving target.

- Interactive Info Panel (UI): created a window in the bottom-left corner that displays real-time statistics (mass, diameter), descriptions, data and a photo gallery for the selected planet.

- Planetary Satellites: added moons (e.g., The Moon, Io, Titan) that orbit their parent planets, visible when zooming in.

- Asteroid Belt: generated a visual belt of asteroids orbiting between Mars and Jupiter

- Comets: implemented a system that randomly spawns comets traversing the solar system with a visual trail.

- Date Counter: added a dynamic display that tracks the current simulation year (starting 2025) and day based on the speed.




---------------------------

3. Project Changes & Design Decisions: (milestone)
During the development, we made a few adjustments to the initial idea:

- Addition of Zoom Functionality: we realized that the distance between Mercury and Neptune is too large to fit on a single screen without making the inner planets invisible.

- Use of Image Assets: to make the simulation more engaging than just moving colored dots.

- Relative Coordinate Rendering: to support the "Camera Tracking" feature, we refactored the drawing logic. Instead of calculating positions relative to the screen center, positions are now calculated relative to the currently "locked" body.


---------------------------



4. Next Steps: (milestone)
- We discussed the possibility of adding interactive buttons to increase or decrease the simulation speed.

- Enhance the hover/click info: currently, we have a visual highlight; the next step is to display a text box with specific data (mass, gravity, day length) when a planet is selected.



---------------------------

5. Project Changes & Design Decisions: 

During the final development phase, we expanded the project scope:

From Passive to Interactive: We shifted from a simple visual simulation to an interactive tool. We added the "Mission Mode" which required implementing a prediction algorithm to calculate where a planet will be in the future to ensure the probe hits it.

UI Design: We moved from simple hover effects to a persistent GUI panel. This allows the user to read information without having to keep the mouse perfectly still over a moving planet.



---------------------------

