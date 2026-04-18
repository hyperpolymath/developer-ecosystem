defmodule ShellState.State do
  @moduledoc """
  In-memory working state for ShellState.
  
  This module manages the ephemeral resident state that is loaded from
  the canonical manifest and modified during runtime. All changes are
  kept in memory until explicitly committed.
  """
  
  defstruct [
    :manifest,
    modified: false,
    integrity_hash: nil
  ]

  @type t :: %__MODULE__{}

  @spec new(ShellState.Manifest.t()) :: t
  def new(manifest) do
    %__MODULE__{
      manifest: manifest,
      modified: false,
      integrity_hash: compute_hash(manifest)
    }
  end

  @spec compute_hash(ShellState.Manifest.t()) :: String.t()
  defp compute_hash(manifest) do
    # Canonicalize to map, compute hash
    manifest
    |> Map.from_struct()
    |> Jason.encode!()
    |> :crypto.hash(:sha256)
    |> Base.encode16()
  end

  @spec mark_modified(t) :: t
  def mark_modified(%__MODULE__{} = state) do
    %{state | modified: true}
  end

  @spec is_modified?(t) :: boolean()
  def is_modified?(%__MODULE__{modified: true}), do: true
  def is_modified?(_), do: false
end