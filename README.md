Position streaming based follow through ipc

Command List (Prefix: //pf)

**ROLE & CONTROL**
**master** : Sets your role to Master (records/sends path via IPC).
**slave** : Sets your role to Slave (receives/follows path). (Default on load)
**start** : Activates the pathfinding loop. (Starts automatically on load)
**stop** : Halts the pathfinding loop (Slave stops running, Master stops recording).

**QUEUE MANAGEMENT**
**clear** : Clears all recorded nodes currently stored in the queue.
**status / s** : Shows the current path queue length and settings.

**FILE I/O**
**export <filename.txt>** : (Slave Only) Saves the current path queue to a file in the /paths folder.
**import <filename.txt>** : (Slave Only) Loads a path from the /paths folder, replacing the current queue.
**mark** : (Master Only) Records your current position to a sequential mark_N.txt file.

**TUNING**
**send <dist>** : (Master Only) Sets min. distance (yalms) Master moves before sending an update. 
**jump <dist>** : (Slave Only) Sets the max distance (yalms) between nodes before clearing the queue (teleport detection). 
**interval <hz>** : Sets the addon clock rate 
**help** : Displays this help message.
