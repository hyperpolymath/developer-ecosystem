// SPDX-License-Identifier: PMPL-1.0-or-later
// DogTraining  Dog combat practice scenarios
//
// Spawns RoboDog and GuardDog for the player to practise
// stomp mechanics and avoidance tactics.
//
// Scenarios:
//   - RoboDog: Learn body-bounce vs head-KO stomp distinction.
//   - GuardDog: Learn scent detection range, food distraction.
//   - Mixed pack: RoboDog + GuardDog together. Practise prioritisation.

let config: TrainingBase.trainingConfig = {
  title: "Dog Handling Training",
  instructions: [
    "Jump and land on a dog's HEAD for a KO (instant disable).",
    "Land on a dog's BODY for a bounce (temporary stun).",
    "GuardDogs detect by scent (360 degrees)  they always know where you are.",
    "RoboDogs use cameras (narrow cone)  approach from behind.",
  ],
  arenaWidth: 1200.0,
  groundY: 500.0,
}

let setupEntities = (gameState: GameLoop.gameState, _worldContainer: Pixi.Container.t): unit => {
  let dogs = [
    // RoboDog  camera-based detection, hackable
    SecurityDog.make(
      ~id="train_robodog",
      ~variant=RoboDog,
      ~x=600.0,
      ~y=500.0,
      ~waypoints=[{x: 450.0, pauseDurationSec: 2.0}, {x: 750.0, pauseDurationSec: 2.0}],
      (),
    ),
    // GuardDog  scent-based detection, food-distractable
    SecurityDog.make(
      ~id="train_guarddog",
      ~variant=GuardDog,
      ~x=900.0,
      ~y=500.0,
      ~waypoints=[{x: 800.0, pauseDurationSec: 1.5}, {x: 1050.0, pauseDurationSec: 1.5}],
      (),
    ),
  ]
  gameState.dogs = dogs
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
    ~legendEntries=TrainingBase.dogLegendEntries,
  )
}

let constructor: Navigation.appScreenConstructor = {
  make,
  assetBundles: Some(["main"]),
}

let _ = constructorRef := Some(constructor)
