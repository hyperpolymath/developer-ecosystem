# IDApTIK Moletaire System Upgrade / Consolidation Spec
# Coding-AI-ready implementation brief

## Goal

Consolidate and extend the `Moletaire` companion system into a clear, testable, game-feel-driven subsystem that a coding AI can safely evolve without flattening its character.

Moletaire must remain:

- a **companion**, not a second full player avatar
- partially obedient, but not perfectly obedient
- mechanically useful, but often awkward, risky, hungry, distractible, or fragile
- a source of emergent stories, not just a tool with buttons

The key design rule is:

- **Jessica is the primary player character**
- **Moletaire is a semi-autonomous companion the player can direct**
- **Moletaire's value comes from unusual traversal and sabotage**
- **Moletaire's danger comes from hunger, distraction, dogs, falls, and being physically small/vulnerable**

Do not "improve away" the awkwardness.
Do not turn Moletaire into a clean, perfectly responsive sidekick.

---

## Repo / implementation context

This spec targets the live `idaptik` repo structure, especially:

- `src/app/companions/Moletaire.res`
- `src/app/screens/training/MoletaireTraining.res`
- `src/app/screens/training/HighwayCrossingTraining.res`
- `src/app/screens/training/DroneTraining.res`
- `src/app/screens/training/TrainingBase.res`
- `src/app/enemies/Drone.res`
- `src/app/enemies/SecurityDog.res`

Moletaire already exists in code with:
- hunger tuning constants
- equipment enums
- a defined mole state machine
- game-level event signalling to the caller

Training content already exists for:
- trap digging
- USB carry / delivery
- dog confusion interactions
- building climb / jump / catch
- hunger pressure

Implement changes by extending or refactoring the current system, not by replacing it with an unrelated architecture.

---

## World assumptions

Use these gameplay entities consistently:

- `Jessica`: the main human player character
- `Moletaire`: companion mole
- `Guard`: standard security human
- `SecurityDog` / `RoboDog`: anti-mole / anti-intruder canine unit
- `Drone`: helper / hunter / killer style support units
- `Building`: may have doors, floors, windows, rooftops
- `ObjectiveItem`: USB drive, evidence, sabotage target, etc.
- `FoodPellet` / edible lure / components / loose wires

Moletaire must interact asymmetrically with all of the above.

---

## Core gameplay identity

Moletaire is a specialist infiltration companion with five defining traits:

1. **Underground traversal**
   - can move underground where Jessica cannot
   - underground movement is often safer, but not always
   - depth matters

2. **Small-scale sabotage**
   - trap digging
   - cable sabotage
   - carrying small items
   - stealing / delivering mission objects
   - interacting with awkward spaces

3. **Semi-autonomy**
   - the player can guide Moletaire
   - hunger and distraction can override or distort player intent
   - some behaviours should be involuntary

4. **High vulnerability**
   - dogs are a serious threat
   - falls can kill
   - traps can backfire
   - getting caught can be terminal outside training

5. **Equipment-driven variation**
   - head/body equipment should change how Moletaire is useful
   - equipment must feel distinct, not cosmetic

---

## Design rule: preserve friction

Do not turn Moletaire into:
- a fast, all-purpose stealth hero
- a perfect drone-like remote body
- a creature with no appetites or instincts
- a minigame token disconnected from the main game

Preserve:
- awkwardness
- appetite
- partial disobedience
- niche strengths
- specific dangers

The system is correct only if the player sometimes thinks:
- "this little menace is useful"
- "why is he doing that"
- "I should have planned around his hunger / dog risk / fall risk"

---

## Confirmed current model to preserve

The current code already establishes:

### Core state machine
Use and extend this conceptual state model:

- `Idle`
- `MovingUnderground`
- `MovingAboveGround`
- `DiggingTrap`
- `SabotagingCable`
- `CarryingItem`
- `Distracted`
- `Gliding`
- `Crushed`
- `CaughtByDog`
- `Dead`

Do not replace this with a single generic "Active" state.

### Equipment model
Current equipment shape already supports:

Head slot:
- `Flash`
- `BatteringRam`
- `Camera`
- `Miniglider`

Body slot:
- `Skateboard`
- `NoBody`

This should remain an explicit typed loadout system, not ad-hoc booleans.

### Hunger model
Preserve the current conceptual hunger system:

- hunger rises over time
- above threshold, Moletaire resists control intermittently
- above starving threshold, Moletaire may autonomously move toward food
- hunger is gameplay, not just UI flavour

---

## High-level architecture

Implement Moletaire as:

1. **shared companion core**
2. **behaviour submodules**
3. **explicit tunable config**
4. **training-only overrides where needed**

Recommended structure:

- `MoletaireCore`
- `MoletaireState`
- `MoletaireEquipment`
- `MoletaireHunger`
- `MoletaireDogInteraction`
- `MoletaireBuilding`
- `MoletaireTrainingHooks`

or equivalent internal functions within existing files.

Prefer:
- explicit state transitions
- event-driven consequences
- tuneable data tables
- isolated logic for hunger / dogs / buildings / equipment

Avoid:
- one giant monolithic `update` that mixes everything
- hidden magic numbers scattered across unrelated code
- flattening all special mechanics into "just movement"

---

## Control model

Moletaire is controlled in parallel with Jessica, but must not feel like a second full character sheet.

### Main training / general controls
Conceptual command set:

- move left
- move right
- toggle underground / climb floor
- dig trap
- pick up / deliver / eat / enter building

Implementation rule:
these actions should map cleanly to current keybind infrastructure, but the system logic must not depend on hard-coded keyboard letters.

Prefer:
- command abstraction layer
- training screen can bind keys
- Moletaire logic consumes semantic commands, not raw keycodes

### Companion control principle
The player issues intentions.
Moletaire may:
- comply
- comply slowly
- refuse due to hunger
- be diverted by distraction
- be prevented by state constraints

That friction is required.

---

## State machine requirements

### Idle
Use when:
- no active movement
- no task
- no involuntary behaviour

Can transition to:
- underground movement
- above-ground movement
- item interaction
- trap digging
- sabotage
- distraction
- building interaction

### MovingUnderground
Identity:
- main stealth / traversal mode
- fast compared to above-ground movement
- may generate detectable noise
- depth is tactically important

Requirements:
- can move efficiently through valid tunnelable zones
- should expose depth or effective depth to other systems
- dogs and some drone effects must react differently depending on depth

### MovingAboveGround
Identity:
- slow, vulnerable, awkward surface mode
- useful for buildings, items, or crossing specific spaces

Requirements:
- clearly slower than underground movement
- skateboard body equipment can modify this
- above-ground exposure should increase danger from dogs / guards / drones

### DiggingTrap
Identity:
- deliberate setup action
- must require time commitment
- should only work underground or in valid trap-capable terrain

Requirements:
- fixed channel duration
- interruption rules
- game event emitted on completion
- risk of backfire if Moletaire remains badly positioned

### SabotagingCable
Identity:
- short sabotage interaction
- should feel distinct from trap digging

Requirements:
- fixed timed channel
- valid target required
- emits world-level sabotage event
- must be interruptible

### CarryingItem
Identity:
- Moletaire can carry only limited payload by default
- carrying should be meaningful and slightly risky

Requirements:
- default capacity is one small item
- movement or behaviour may be affected while carrying
- delivery has a non-zero chance to be disrupted by hunger / eating impulse

### Distracted
Identity:
- involuntary attraction to tempting nonsense like loose wires

Requirements:
- distraction should override direct player intention for a short time
- distraction should feel stupid but readable
- distraction should be escapable only when timer / stimulus ends or stronger event interrupts

### Gliding
Identity:
- special movement state tied to `Miniglider`
- not fully controllable
- height converts into travel distance

Requirements:
- keep it partially uncontrollable
- treat as committed motion, not free flight
- useful but dangerous
- should interact with catch / fall / building systems

### Crushed
Identity:
- failure state caused by trap backfire or similar heavy-impact consequence

Requirements:
- terminal in normal gameplay
- training may respawn instead of permadeath

### CaughtByDog
Identity:
- dog successfully dug down or caught Moletaire

Requirements:
- terminal in normal gameplay
- training may respawn instead

### Dead
Identity:
- final terminal state
- no active control except respawn / reset flows

---

## Movement and traversal rules

### Underground traversal
Underground is Moletaire's signature strength.

Required properties:
- faster than surface movement
- safer from some threats
- not completely safe
- should generate detectable disturbance/noise in some cases
- depth must matter

Depth bands should be represented explicitly, not as pure flavour.

Recommended conceptual bands:
- shallow
- medium
- deep

These do not need to be discrete enums if a float depth is already in use, but the gameplay must behave as if depth bands exist.

### Above-ground traversal
Above-ground should feel:
- exposed
- clumsy
- sometimes necessary

It is where:
- item pickup happens
- building entry often happens
- dogs become more dangerous
- equipment like skateboard matters most

### Building traversal
Buildings are a special Moletaire mechanic, not ordinary platforming.

Current intended flow:
- enter at door
- climb floor-by-floor
- jump from top
- Jessica catches on ground if positioned correctly

Required properties:
- building entry must be readable
- floor climbing must be discrete and understandable
- catch zone must be legible
- failure to catch should have consequence

Do not make building traversal a generic ladder system unless that is the intended design everywhere.

---

## Equipment system

## Equipment philosophy

Equipment must create new possibilities, not tiny stat nudges.

### Head equipment

#### Flash
Effect:
- short-range stun on nearby enemies

Design rules:
- emergency utility, not constant spam
- strong in a pinch
- likely cooldown-limited or charge-limited
- useful for escape windows

#### BatteringRam
Effect:
- break window-like obstacles or other ram-valid breakables

Design rules:
- must enable route creation or target access
- should be noisy / risky enough to matter
- do not make it open everything

#### Camera
Effect:
- night vision and evidence collection

Design rules:
- should improve scouting / objective handling
- may interact with darkness systems
- may unlock optional mission value, not just survival

#### Miniglider
Effect:
- glide from height with limited / reduced control

Design rules:
- preserve awkwardness
- trajectory should matter
- pairs naturally with building climbing and catch/fall systems

### Body equipment

#### Skateboard
Effect:
- boosts above-ground movement meaningfully

Design rules:
- surface mobility upgrade, not universal mobility
- should not negate underground identity
- may increase instability or visibility if desired

#### NoBody
Default baseline.

### Planned equipment

#### Rucksack
Design intent:
- expanded carry capacity

Requirements:
- capacity increase must have tradeoff
- do not make default carry limit irrelevant
- should integrate with delivery / hunger risk / retrieval design

#### Combined Camera + Flash option
Do not implement casually.
Requires explicit design choice:
- merged utility
- cost / tradeoff
- slot rule implications

---

## Hunger system

## Core identity

Hunger is not cosmetic.
It is the main source of semi-autonomy and misbehaviour.

### Required behaviour
Hunger must:
- increase over time
- create intermittent control resistance
- drive autonomous food-seeking at high levels
- create risk to objectives if Moletaire is starving
- sometimes make the player choose between mission progress and feeding

### Behaviour bands

#### Sated / low hunger
- obeys normally
- no control interference
- low risk of eating wrong thing

#### Hungry
- intermittent resistance begins
- player still mostly in control
- movement / task execution can be disrupted

#### Starving
- Moletaire may autonomously move toward edible targets
- may consume inappropriate items or objectives
- should feel urgent and annoying, not random

### Hunger interaction rules
Hunger can affect:
- responsiveness
- delivery reliability
- distraction susceptibility
- food prioritisation
- willingness to ignore commands

Do not make hunger a pure countdown to death unless that is added deliberately later.

### Training overrides
Training should exaggerate hunger enough to make the mechanic visible quickly.

Acceptable training-only changes:
- faster hunger rate
- extra food pellets
- respawning food
- more obvious hunger UI / VFX

Do not silently change main-game tuning just to make training clearer.

---

## Item interaction system

Moletaire should remain a **small-item specialist**.

### Currently expected interactions
Support at minimum:
- pick up item
- carry item
- deliver item
- eat food
- be distracted by tempting junk
- possibly eat the wrong thing when hungry enough

### Default inventory rule
By default:
- only one carryable item at a time

Do not increase this unless equipment or explicit design changes it.

### Delivery rule
Deliveries should not always be safe.
There should remain some chance of:
- hesitation
- hunger interference
- accidental consumption for certain item categories

### Item categories
Recommended conceptual categories:
- objective item
- edible
- distraction item
- sabotage target
- evidence item
- equipment pickup

Make category handling explicit where possible.

---

## Dog interaction system

Dogs are one of Moletaire's defining counters.

## Core design rule
Dogs should detect Moletaire primarily through **sound / disturbance**, not conventional facing-based vision.

### Detection model
Use a circular proximity / hearing-style model for underground mole disturbance.

Dogs should react based on:
- distance
- Moletaire depth
- whether Moletaire is moving or making noise
- confusion state
- current dog mode

### Depth-sensitive threat model
Required qualitative bands:

#### Very shallow
- dogs can successfully dig / catch
- this is the danger zone

#### Medium shallow
- dogs can hear and react strongly
- pacing / pawing / hovering overhead
- threatening but not immediately fatal

#### Deep enough
- dogs may hear faintly or ignore
- relatively safe band

### Confusion mechanic
Preserve the "pop up on alternating sides" behaviour.

Required result:
- if Moletaire rapidly side-switches relative to a dog multiple times within a short window,
  the dog becomes confused temporarily

While confused:
- reduced tracking
- reduced digging threat
- readable confused animation / behaviour
- no instant re-lock unless confusion ends cleanly

This should feel like a clever mole trick, not an exploit accidentally caused by pathing bugs.

### Dog priority rules
When in dedicated mole-hunt mode:
- the dog should focus on Moletaire
- player/Jessica detection logic may need suppression or special handling to avoid unfair chain failure

This is an important integration constraint.
Do not let "dog chasing mole" accidentally trigger player-loss logic unless intentionally designed.

---

## Building / climb / jump / catch system

Buildings must support a distinct Moletaire loop.

### Core flow
1. Moletaire reaches building entrance
2. enters building
3. climbs upward floor-by-floor
4. jumps from top
5. Jessica catches or fails to catch

### Entry rules
- entry zone must be generous enough to use reliably
- must have a visual affordance / prompt
- should not require pixel-perfect alignment

### Climb rules
- each climb action advances one floor
- floor state should be explicit
- top floor jump transition must be deterministic

### Catch rules
- Jessica must be in catch zone
- catch window should be readable
- failure should produce meaningful consequence

### Design constraints
Do not make the catch mechanic invisible or purely inferred.
The player must understand:
- where Jessica should stand
- when Moletaire is about to fall
- whether a catch succeeded

### Optional future extension
Possible future design:
- exit from intermediate floors
- route branching
- equipment-dependent traversal

Do not add this unless it is intentionally designed.

---

## Highway Crossing Mole mode

This is a specialised Moletaire training variant / side mode, not the default behaviour model.

## Identity
A Frogger-like minigame where:
- Moletaire crosses lanes of traffic
- near misses build nausea
- underground travel is safer but slower

### Required design rules
- traffic danger must be readable
- nausea must matter
- underground option must be viable but slow
- hits must punish without making the mode instantly hopeless

### Nausea / car-sickness model
Nausea should:
- increase on near-miss
- spike on collision
- decay over time
- cause slower movement / sluggish response

This mechanic should feel comedic and inconvenient, not realistic simulation.

### Collision rule
Use robust collision handling suitable for fast-moving hazards.
Do not allow small vehicles to phase through the mole between frames.

### Mode separation
Keep highway-crossing logic isolated from core companion behaviour where possible.
It is a training / side-mode specialisation.

---

## Drone interaction requirements

Moletaire must have meaningful interactions with drone systems.

### Helper drones
- may interfere with his trap outcomes by rescuing victims
- may be distractible toward him
- may alter movement space through building-lift support

### Hunter drones
- may track or flush him using search / coordination tools
- may use sonic or flare-like search amplification
- should make underground evasion harder through coordination

### Killer drones
- represent extreme danger
- may snatch / carry / drop Moletaire
- should be among the strongest anti-Moletaire threats

### Anti-drone counterplay
Moletaire should remain relevant against drones via:
- depth / underground movement
- sabotage
- misdirection
- equipment
- awkward route use
- baiting dumb or overcommitted AI

Do not let drones trivially erase his niche.

---

## Training design requirements

Training content should teach **what Moletaire is like**, not just which buttons he has.

### Moletaire training should teach
- tunnelling vs surface risk
- trap digging
- item carrying
- dog danger
- dog confusion trick
- building climb / jump / catch
- hunger pressure
- distraction risk

### Drone training should teach
- how drone types threaten Jessica and Moletaire differently
- helper / hunter / killer asymmetry if/when upgraded
- anti-drone timing and movement

### Highway training should teach
- timing under stress
- nausea consequences
- safe-vs-fast route choice

### Training-only concessions
Allowed:
- respawn instead of permadeath
- exaggerated UI
- simplified layouts
- faster hunger
- denser pickups

Not allowed:
- removing the defining awkwardness of the companion

---

## Event model

Moletaire should report world-significant outcomes upward rather than silently mutating unrelated systems.

Recommended conceptual events:
- `TrapTriggered`
- `TrapCompleted`
- `TrapFailed`
- `CableSabotaged`
- `ItemPickedUp`
- `ItemDropped`
- `ItemDelivered`
- `ItemEaten`
- `FoodEaten`
- `EnteredBuilding`
- `ClimbedFloor`
- `JumpedFromBuilding`
- `CaughtByJessica`
- `MissedCatch`
- `DogDetectedMole`
- `DogCaughtMole`
- `HungerResistanceStarted`
- `HungerResistanceEnded`
- `DistractedByWire`
- `GlideStarted`
- `GlideEnded`
- `Died`

Exact names can vary, but the architecture should preserve eventful boundaries.

---

## Tunables

All of these must be explicit tuning data, not buried magic constants:

- underground speed
- above-ground speed
- skateboard surface speed
- trap dig duration
- sabotage duration
- distraction duration
- hunger rate
- hunger threshold
- starving threshold
- hunger resistance interval
- hunger resistance duration
- hunger-driven movement speed
- delivery eat chance
- dog hearing range
- dog shallow-detection depth
- dog fatal-dig depth
- dog confusion threshold
- dog confusion duration
- building door width
- building catch radius
- glider distance factor
- item pickup radius
- food respawn timing
- training-only overrides for hunger / respawn / UI

Keep main-game and training overrides clearly separated.

---

## Integration constraints

### Jessica + Moletaire coexistence
The player controls both systems in one scenario.
Avoid conflicts where:
- Moletaire input steals Jessica input unexpectedly
- dog mole-chase logic causes unfair Jessica fail state
- building / catch state desynchronises from Jessica position
- hunger AI fights the player in unreadable ways

### Persistence
If persistence already exists, preserve it.
Equipment and relevant Moletaire state should remain compatible with current persistence shape unless a migration is intentionally introduced.

### Audio / feedback
Underground movement music / SFX is part of identity.
Preserve or improve:
- underground audio cues
- hunger feedback
- dog hearing / scratching cues
- distraction cues
- building / catch anticipation cues

### Visual clarity
Prioritise readability for:
- current state
- hunger
- underground vs surface
- carry status
- equipment
- dog attention
- catch zone
- distraction / control resistance

---

## Priority implementation areas

### High priority
1. preserve and cleanly expose the core state machine
2. equipment spawning / selection in training
3. building entry readability and wider usable hitbox
4. dog-vs-mole chase integration without unfair Jessica fail state
5. hunger visibility and training pacing
6. explicit event and tuning boundaries

### Medium priority
1. better feedback for food eating
2. better dog hearing / pawing visualisation
3. more food spawn / respawn logic
4. clearer building catch-zone feedback
5. cleaner training scenario completion logic

### Lower priority / expansion
1. rucksack
2. combined camera/flash design
3. highway power-ups / traffic phases
4. richer drone countermeasures specific to Moletaire
5. more advanced building routes

---

## Acceptance criteria

The implementation is correct only if all of the following are true in gameplay:

1. Moletaire feels distinct from Jessica rather than like a reskinned second player.
2. Underground movement is his signature strength.
3. Surface movement is clearly weaker and riskier.
4. Hunger sometimes interferes with control in a readable way.
5. At high hunger, Moletaire may pursue food or consume the wrong thing.
6. Dogs are a real anti-mole threat, especially at shallow depth.
7. Rapid side-switching can confuse dogs and create a temporary escape window.
8. Trap digging is useful but can backfire.
9. Building climb / jump / catch is understandable and not pixel-perfect nonsense.
10. Equipment materially changes what Moletaire can do.
11. Training teaches the companion's awkward strengths and weaknesses honestly.
12. The player can tell, by observation, whether Moletaire is idle, tunnelling, distracted, hungry, gliding, carrying, or in danger.

---

## Test scenarios

Implement automated tests, debug harnesses, or manual validation scenarios for:

1. **Hunger resistance test**
   - hunger crosses threshold
   - periodic control resistance begins
   - resistance ends correctly

2. **Starvation misbehaviour test**
   - hunger crosses starving threshold
   - food exists nearby
   - Moletaire pathing biases toward food
   - objective-eating risk is preserved where intended

3. **Trap success / backfire test**
   - trap completes
   - victim falls
   - mole dodge / survival logic works
   - crushed failure remains possible

4. **Dog shallow-depth kill test**
   - mole underground but too shallow
   - dog detects and can catch

5. **Dog medium-depth harassment test**
   - dog reacts / paws / tracks
   - cannot immediately kill

6. **Dog confusion test**
   - rapid side-switching occurs
   - confusion triggers
   - confusion duration expires properly

7. **Building entry test**
   - entry prompt / hitbox is usable
   - mole enters reliably

8. **Building catch test**
   - Jessica in zone => successful catch
   - Jessica absent => failure consequence

9. **Equipment differentiation test**
   - skateboard changes surface traversal clearly
   - miniglider changes fall/jump behaviour clearly
   - flash / ram / camera each unlock distinct interactions

10. **Training hunger visibility test**
   - hunger mechanic becomes visible early enough during training
   - does not require very long idle waiting

11. **Carry-and-deliver test**
   - one-item capacity enforced by default
   - delivery works
   - delivery eat-risk remains

12. **Highway collision robustness test**
   - small fast vehicles cannot tunnel through the mole between frames

---

## Output expectation for the coding AI

Produce:

1. updated Moletaire type / state definitions only where needed
2. explicit tuning/config tables
3. clear separation of hunger, dog, building, and equipment logic
4. integration-safe event handling
5. training-only override hooks
6. comments explaining the behavioural intent
7. small test harnesses or validation scenarios
8. no deprecated API usage
9. no flattening of Moletaire into a simple obedient pet

When uncertain, preserve gameplay character over technical neatness.
