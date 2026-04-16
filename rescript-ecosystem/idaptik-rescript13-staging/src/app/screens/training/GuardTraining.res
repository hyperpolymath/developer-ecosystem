// SPDX-License-Identifier: PMPL-1.0-or-later
// GuardTraining  Guard combat practice scenarios
//
// Spawns guards of different ranks for the player to practise
// stomp and sprint-charge knockdown mechanics.
//
// Scenarios:
//   - BasicGuard: 1 slow guard patrolling. Learn sprint-charge knockdown.
//   - EliteGuard: Faster, harder to approach. Practise timing.
//   - Sentinel: Immovable, wide detection. Immune to knockdown  learn to avoid.
//   - Assassin: Hidden ambusher. Immune to knockdown  learn to detect and dodge.

let config: TrainingBase.trainingConfig = {
  title: "Guard Combat Training",
  instructions: [
    "Sprint (Shift) into guards to knock them down with a charge.",
    "Jump (Space/W) and land on guards to stomp them.",
    "Sentinel and Assassin are IMMUNE to knockdown  avoid them!",
  ],
  arenaWidth: 1200.0,
  groundY: 500.0,
}

let setupEntities = (gameState: GameLoop.gameState, _worldContainer: Pixi.Container.t): unit => {
  // Spawn a variety of guards for practice
  let guards = [
    // Basic guard  slow patrol, easy target for charge/stomp
    GuardNPC.make(
      ~id="train_basic",
      ~rank=BasicGuard,
      ~x=500.0,
      ~y=500.0,
      ~waypoints=[{x: 400.0, pauseDurationSec: 3.0}, {x: 700.0, pauseDurationSec: 3.0}],
    ),
    // Elite guard  faster, shorter pauses
    GuardNPC.make(
      ~id="train_elite",
      ~rank=EliteGuard,
      ~x=800.0,
      ~y=500.0,
      ~waypoints=[{x: 700.0, pauseDurationSec: 1.0}, {x: 1000.0, pauseDurationSec: 1.0}],
    ),
    // Sentinel  stationary, immune to knockdown
    GuardNPC.make(~id="train_sentinel", ~rank=Sentinel, ~x=1050.0, ~y=500.0, ~waypoints=[]),
  ]
  gameState.guards = guards
}

let constructorRef: ref<option<Navigation.appScreenConstructor>> = ref(None)

let make = (): Navigation.appScreen => {
  TrainingBase.makeTrainingScreen(
    config,
    ~setupEntities,
    ~onBack=TrainingBase.backToMenu,
    ~onReset=() => {
      switch (GetEngine.get(), constructorRef.contents) {
      | (Some(engine), Some(c)) => Navigation.showScreen(engine.navigation, c)->ignore
      | _ => ()
      }
    },
    ~selfConstructor=?constructorRef.contents,
    ~legendEntries=TrainingBase.guardLegendEntries,
  )
}

let constructor: Navigation.appScreenConstructor = {
  make,
  assetBundles: Some(["main"]),
}

let _ = constructorRef := Some(constructor)
