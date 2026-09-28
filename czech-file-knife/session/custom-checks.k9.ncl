K9!
# SPDX-License-Identifier: MPL-2.0
# Local repository session checks (thin policy layer)

{
  pedigree = {
    schema_version = "1.0.0",
    metadata = {
      name = "custom-session-checks",
      version = "0.1.0",
    },
    security = {
      leash = 'Kennel,
    },
  },

  checks = [
    {
      id = "session-state-has-next-action",
      applies_to = [
        "close planned",
        "close urgent",
        "handover full",
        "handover split",
        "handover model",
        "handover human",
      ],
      requirement = "LAST-CANONICAL-COMMAND.md contains next intended action",
    },
    {
      id = "session-state-has-residual-risks",
      applies_to = [
        "verify maintenance",
        "verify substantial",
        "verify release",
        "recover repo",
      ],
      requirement = "Residual risks field is not left blank",
    },
    {
      id = "session-state-has-recommended-next-protocol",
      applies_to = [
        "intake repo",
        "checkpoint change",
        "recover repo",
        "handover full",
      ],
      requirement = "Recommended next protocol is set",
    },
  ],
}
