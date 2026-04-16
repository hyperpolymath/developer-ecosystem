// SPDX-License-Identifier: PMPL-1.0-or-later
// TrainingRegistry  Breaks circular dependency between WorldMapScreen and TrainingMenuScreen
//
// WorldMapScreen needs to navigate to TrainingMenuScreen, but TrainingMenuScreen
// navigates back to WorldMapScreen. This registry lets WorldMapScreen look up
// the training menu constructor without importing it.

let trainingMenuConstructor: ref<option<Navigation.appScreenConstructor>> = ref(None)

let navigateToTraining = (): unit => {
  switch (GetEngine.get(), trainingMenuConstructor.contents) {
  | (Some(engine), Some(c)) =>
    let _ = Navigation.showScreen(engine.navigation, c)->Promise.catch(PanicHandler.handleException)
  | _ => Console.error("[TrainingRegistry] Engine or training menu constructor not available")
  }
}
