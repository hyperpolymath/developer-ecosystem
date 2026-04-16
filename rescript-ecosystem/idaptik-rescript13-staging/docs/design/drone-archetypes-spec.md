# IDApTIK Drone System Upgrade Spec
# Coding-AI-ready implementation brief

## Goal

Replace or extend the current drone behaviour system with three distinct drone archetypes:

- `HelperDrone`
- `HunterDrone`
- `KillerDrone`

This system must feel asymmetrical, systemic, and gameable rather than fair or perfectly rational.
The key design rule is:

- **Helper drones are strong but stupid**
- **Hunter drones are smart but fragile**
- **Killer drones are lethal, focused, and dangerous partly because they are predictable**

Do not make all drones share the same AI quality. Their intelligence, perception, resilience, movement, and priorities must differ substantially.

---

## World assumptions

Use these gameplay entities consistently:

- `Jessica`: the main human player character
- `Moletaire`: mole companion / non-human ally
- `Guard`: human security ally to the drones
- `SecurityDog` / `RoboDog`: dog unit allied with security
- `Building`: may have external doors, internal doors, balconies, windows, rooftop, underground spaces

Assume the game already has guards, dogs, distraction systems, and drone code.
Integrate with existing enemy / detection / distraction systems instead of inventing a separate mini-engine.

---

## High-level architecture

Implement this as:

1. a **shared drone core**
2. plus **archetype-specific behaviour policies**

Recommended structure:

- shared movement / state / targeting / perception utilities in drone core
- behaviour override modules or per-archetype strategy tables
- explicit tunable constants for all ranges, speeds, thresholds, and timers

Do **not** hard-code behaviour directly into one giant update function unless that is already unavoidable in the existing module.
Prefer a data-driven or strategy-driven approach where possible.

---

## New drone archetypes

### 1. Helper drone

## Fantasy

A slow, mechanical, physically resilient rescue / support drone that is bad at judgement.

## Core behaviour identity

Helper drones are intentionally dumb.

They should:
- take bad routes surprisingly often
- fail to prioritise well under uncertainty
- become distracted by Moletaire
- hesitate under risk
- sometimes get stuck in indecision
- be physically hard to destroy
- be electronically simple and therefore less meaningfully hackable

They are not "smart support AI".
They are closer to stubborn, literal, rescue-capable machines.

## Movement

- slow
- mechanical
- non-agile
- no diagonal movement unless the existing engine absolutely requires it
- poor obstacle reasoning
- can collide with scenery if distracted
- cautious pathing around hazards
- often aborts or delays when risk is non-trivial

## Rescue / support actions

Helper drones can:
- revive downed guards or dogs slowly
- repair allied units slowly
- lift and evacuate guards or dogs
- transport rescued units toward safe positions

These actions must be unreliable under stress.

Failure modes must include:
- slow pickup attachment
- taking off too early before target is properly attached
- dropping carried units
- flying close to a target, then taking off again without successful pickup
- abandoning rescue if threat evaluation spikes

## Perception

Very limited sensors except what is needed for support tasks.

They should be poor at:
- identifying deception
- complex target discrimination
- long-range search
- robust threat classification

## Distraction rules

Helper drones are unusually distractible by Moletaire.

If Moletaire is visible and the helper drone is not strongly locked onto a rescue task:
- it may follow Moletaire
- it may stop assisting its intended ally
- it may lose awareness of collisions and nearby obstacles

This distraction should be stronger than normal lure behaviour.

## Threat response

Helper drones:
- know killer drones are dangerous
- tend to avoid areas where killer drones are present
- may retreat or abort helping when killer drones arrive
- are generally over-cautious

## Electronic resilience

They are relatively immune to "smart device" attacks because they are simple and dumb.

Interpret this as:
- advanced hacks should often have reduced effect
- when affected electronically, they usually become slower, disabled, or simplistic rather than subverted into complex new behaviour

## Physical resilience

Very high resistance to physical damage.

They should be the toughest drone physically.

## Coordination dependency

Hunter drones can improve helper performance using lidar guidance.

When a helper drone has an active hunter lidar lock guiding it:
- path hesitation is reduced
- target focus is improved
- wrong-priority behaviour is reduced
- rescue commitment is increased

Do not make this perfect; it should be an assist, not mind control.

---

### 2. Hunter drone

## Fantasy

A moderately fast recon / command drone with advanced AI, broad situational awareness, strong coordination tools, and fragile hardware.

## Core behaviour identity

Hunter drones are the "brains" of drone coordination.

They should:
- make good decisions
- learn quickly
- coordinate other drones and guards
- perform area illumination and deception support
- rarely do obviously stupid things unless jammed, scrambled, or cleverly baited

## Movement

- moderately fast
- stable, deliberate flight
- better pathing than helper drones
- less aggressive than killer drones
- should reposition to improve information quality

## Sensors and tools

Hunter drones have the following:

### Light cone
A light cone that can face:
- down
- sideways
- up

Coverage:
- approximately 105 degrees regardless of chosen orientation

Interpretation:
- do not model this as a tiny spotlight
- model as a broad directional cone
- orientation should matter tactically

### Sonic detection circle
A circular sound / vibration awareness zone around the drone, comparable in concept to dog hearing.

### Lidar beam
A precise ranging / target designation beam.

Rules:
- can guide guards or other drones to a location
- can guide helper drones to stay focused
- requires maintained beam lock
- loses effect if beam breaks
- can target through ground and into buildings
- should be precise, not merely approximate

### Flares
Hunter drones can eject aerial flares.

Effects:
- illuminate large areas at night
- useful for search, denial of darkness, and coordination

### Tuning forks
Hunter drones can deploy tuning-fork devices into the ground.

Effects:
- create sounds of nearby human movement
- can confuse guards
- affect Jessica
- affect Moletaire even if he is underground, provided he is close enough
- may create confusion if guards do not know Moletaire exists or if he is underground / out of direct context

Treat tuning forks as deliberate sensory manipulation tools, not direct damage tools.

## Coordination

Hunter drones can communicate two-way with:
- other drones
- guards
- likely dog units if supported by current systems

They can:
- share detections
- retask nearby units
- cover exits
- send a hunter drone to another door or rooftop
- coordinate building perimeter checks

Important limitation:
- they **do not** anticipate window exits well
- they **might** inspect balconies
- they are good, but not omniscient

## Fragility

Hunter drones are the most fragile drone type:
- physically fragile
- electronically fragile

This is their balancing weakness.

## AI quality

Very advanced AI.

They should:
- adapt rapidly
- remember recent failed assumptions
- reduce repeated mistakes
- recover from false leads better than helper drones
- be hard to fool repeatedly in the same way

However:
- scrambled signals
- strong distractions
- deliberate counterplay
should still degrade them.

---

### 3. Killer drone

## Fantasy

A very fast, highly manoeuvrable, focused pursuit-and-kill drone that is smart but not broad-minded.

## Core behaviour identity

Killer drones are not generally "the smartest".
They are the most tactically dangerous because they are:
- fast
- relentless
- committed to lethal pursuit
- willing to improvise violence from the environment

Their intelligence is narrow, focused, and aggressive.

## Movement

- very fast
- highly manoeuvrable
- can move left, right, up, down, and diagonally
- only drone type allowed diagonal movement
- can turn sharply
- can pursue through buildings
- can wait outside doors patiently until access opens

Door / structure interaction:
- cannot open doors themselves
- hunter drones can open / close external doors for them
- smart guards can open doors for them
- can smash:
  - non-reinforced windows
  - non-reinforced internal doors

## Behaviour style

Killer drones:
- prioritise killing the enemy over all else
- are not easily distracted
- are more predictable because of their obsession with target elimination
- are usually patient until agitated
- become much more reckless when agitated or frustrated

## Agitation triggers

Agitation should increase when:
- Moletaire is involved
- a robodog is damaged
- a drone is damaged
- an allied unit is reported attacked
- the target escapes repeatedly
- the killer drone is obstructed too long

When agitated:
- patience drops
- collateral-damage tolerance rises
- recklessness increases
- brute-force entry becomes more likely
- kamikaze or environmental-weapon use becomes more likely

## Physical and electronic resilience

Strong against both:
- physical attacks
- electronic attacks

Not invulnerable, but much harder to stop than hunter drones.

## Perception

### Predator sight cone
Killer drones have a narrow but long-range vision model.

Passive mode:
- 50 degree cone
- same distance as standard guard sight

Pursuit mode:
- 30 degree cone
- three times normal guard sight distance

They can tilt up and down to expand practical coverage.

Interpret this as:
- long-range focused hunting
- weaker broad awareness than hunter drones
- excellent pursuit-line tracking

### Audio

Passive mode:
- listening range similar to robodog hearing

Active mode:
- pulse sonar with twice that reach
- sonar can penetrate walls and ground
- same depth penetration concept as its normal sound circle

## Environmental weapon improvisation

Killer drones are the only drone type allowed to improvise weapons from the environment.

They may:
- switch lights off
- switch lights on
- pick up bait objects
- move or drop objects from height
- use objects to flush or mislead targets
- perform kamikaze runs

Do not allow helper or hunter drones to do this at the same level.

## Snatch / drop attack

Killer drones can:
- snatch Moletaire
- carry him high into the air
- drop him

Outcome:
- if Jessica catches him, he survives
- otherwise he splats and is out of the game

This needs explicit gameplay hooks, not just cosmetic animation.

## Cloak

Killer drones can cloak briefly while stationary.

Rules:
- cloak only when stationary
- cloak duration is short
- cloak should be good for ambush / repositioning, not invisibility forever
- taking action, moving, or being disrupted should break cloak

---

## Shared system requirements

### Shared type model

Implement explicit archetype and behaviour state types.

Suggested conceptual model:

- `droneArchetype = Helper | Hunter | Killer`
- `droneState = Idle | Patrol | Investigate | Rescue | Repair | Carry | Guide | Search | Coordinate | Pursue | Attack | Agitated | Retreat | Disabled | Jammed | Scrambled | Cloaked`
- `focusTarget = None | Jessica | Moletaire | Guard(id) | Dog(id) | Drone(id) | Location(vec2) | Exit(id) | Disturbance(id)`

Use more specific sub-states where useful.

### Tunables

All of the following must be tuneable data, not magic constants:
- movement speed
- turn rate
- acceleration
- detection ranges
- hearing ranges
- cone angles
- rescue times
- repair times
- carry-drop probability
- distraction susceptibility
- agitation thresholds
- cloak duration
- flare radius / duration
- tuning fork radius / duration
- lidar guide stability bonus
- damage resistances
- electronic resistance
- patience timers

### State quality differences

Do not give all drone classes equivalent planners.

Required quality gradient:
- helper: weak planner
- hunter: strong planner
- killer: strong but narrow planner

### Counterplay

Each drone type must have meaningful counterplay:

Helper:
- can be lured
- can be confused
- can waste time
- can self-sabotage through caution

Hunter:
- can be scrambled
- can be baited into wrong coverage
- can be broken by fragility
- can lose lidar lock

Killer:
- can be predicted
- can be redirected by baiting its lethal priority
- can be manipulated into overcommitting when agitated
- can be delayed by access constraints

---

## Behaviour rules in priority form

### Helper drone priority order

Base priority:
1. avoid immediate lethal threat
2. continue current rescue if already committed and risk is acceptable
3. assist downed allied guard or dog
4. repair damaged allied unit
5. follow hunter lidar guidance
6. investigate obvious nearby support need
7. become distracted by Moletaire if not strongly committed
8. idle / hover / reposition

Failure rules:
- if priorities are close, helper may stall
- if risk is ambiguous, helper often chooses avoidance
- if distracted, helper may path badly or collide

### Hunter drone priority order

1. maintain information advantage
2. confirm / refine target location
3. coordinate other units
4. cover likely exits
5. illuminate or manipulate search space with flares / tuning forks
6. guide helper drones and guards with lidar
7. personally pursue only when useful
8. retreat if damaged / compromised

### Killer drone priority order

1. kill the designated hostile target
2. maintain pursuit access
3. exploit environment for lethal advantage
4. wait for door / route opening if patience remains
5. force entry if agitated and viable
6. attack Moletaire if tactically useful or emotionally escalated
7. ignore lower-value tasks unless directly relevant to kill

---

## Learning / memory requirements

### Helper
Very weak memory.
Can repeat mistakes.

### Hunter
Strong short-to-medium-term memory.
Should remember:
- recently checked exits
- failed search assumptions
- likely escape routes
- recent detections
- units currently tasked

### Killer
Focused memory.
Should remember:
- last known target path
- blocked access points
- agitation sources
- damage source
- useful environmental weapons nearby

---

## Sensory modelling requirements

Implement perception as multiple channels, not one boolean "can see player".

Possible channels:
- visual cone
- circular hearing
- sonar pulse
- lidar designation
- flare illumination
- tuning fork false-audio event
- communication relays from allied units

Allow some channels to penetrate:
- walls
- ground
- buildings

but only where specified above.

---

## Important limitations to preserve

Do not accidentally "improve away" the personality of the drones.

Preserve these non-ideal behaviours:

- helper drones are often stupid
- helper drones can fail rescues in embarrassing ways
- hunter drones are strong but breakable
- hunter drones are not clairvoyant
- killer drones are brilliant at killing, not at everything
- killer drones are dangerous partly because they are obsessive and therefore exploitable

This system should create stories, not sterile optimisation.

---

## Implementation notes

### Existing code compatibility

Integrate with the current drone / guard / dog / distraction / detection systems rather than replacing unrelated systems.

Where the current drone module already supports:
- tracking
- spotlighting
- jamming
- disabling
- distractions
- battery / return logic

reuse or refactor those ideas where they still fit.

### Recommended approach

Prefer:
- shared `DroneCore`
- `HelperDronePolicy`
- `HunterDronePolicy`
- `KillerDronePolicy`

or equivalent per-archetype functions:
- `updateHelperDrone`
- `updateHunterDrone`
- `updateKillerDrone`

with shared helpers for:
- pathing
- visibility
- hearing
- targeting
- messaging
- damage
- rescue / carry interactions

### Avoid

- one universal AI that only differs by numbers
- making helper drones too competent
- making hunter drones too tanky
- making killer drones too flexible outside pursuit / killing
- overusing randomness without readable cause

---

## Acceptance criteria

The implementation is correct only if all of the following are visibly true in gameplay:

1. Helper drones often make bad support decisions and can be lured by Moletaire.
2. Hunter drones visibly coordinate others and feel like tactical overseers.
3. Hunter lidar meaningfully improves helper focus while the beam is maintained.
4. Killer drones feel terrifyingly fast and lethal.
5. Killer drones wait intelligently at doors, but can become reckless when agitated.
6. Killer drones can weaponise the environment in ways other drones cannot.
7. Hunter drones are the easiest drones to physically or electronically disable.
8. Helper drones are the hardest drones to break physically.
9. Killer drones have the strongest combined pursuit and kill pressure.
10. The three drone classes feel different enough that a player can infer behaviour from observation.

---

## Test scenarios

Implement or simulate these scenarios:

1. **Helper distraction test**
   - downed guard nearby
   - Moletaire appears
   - helper should sometimes abandon or delay rescue

2. **Helper guided rescue test**
   - same setup as above
   - hunter lidar active
   - helper should stay more focused

3. **Hunter exit coverage test**
   - target enters building
   - hunter should task allies to doors / rooftop / balconies
   - should not reliably predict window escape

4. **Hunter tuning fork confusion test**
   - tuning fork deployed near underground Moletaire
   - Moletaire reacts if within range
   - guards may misread what they heard

5. **Killer patience test**
   - target behind closed door
   - killer waits for access first

6. **Killer agitation escalation test**
   - allied robodog damaged
   - killer becomes more reckless and collateral-prone

7. **Killer environmental weapon test**
   - nearby movable object and overhead drop opportunity
   - killer uses object opportunistically

8. **Killer snatch-drop test**
   - Moletaire exposed
   - killer can grab and drop
   - Jessica catch interaction works

9. **Fragility / resilience comparison test**
   - same attack against helper, hunter, killer
   - helper survives longest physically
   - hunter fails fastest
   - killer resists strongly

---

## Output expectation for the coding AI

Produce:

1. updated type definitions
2. per-archetype behaviour logic
3. tunable config tables
4. minimal integration with current guard / dog / distraction systems
5. comments explaining design intent
6. at least a few small scenario tests or debug harnesses
7. no deprecated API usage
8. no flattening of archetype identity into numeric-only differences

When uncertain, preserve gameplay character over technical neatness.
