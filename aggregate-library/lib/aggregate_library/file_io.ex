# SPDX-License-Identifier: PMPL-1.0-or-later

defmodule AggregateLibrary.FileIO do
  @moduledoc """
  Universal file I/O operations based on Elixir's File module.

  Best implementation chosen: Elixir (cleanest Result handling, built-in)

  All operations return {:ok, value} | {:error, reason} tuples for
  consistent error handling across languages.
  """

  @doc """
  Read a file to a string.

  ## Examples

      iex> AggregateLibrary.FileIO.read("test.txt")
      {:ok, "file contents"}

      iex> AggregateLibrary.FileIO.read("nonexistent.txt")
      {:error, :enoent}
  """
  @spec read(Path.t()) :: {:ok, binary()} | {:error, File.posix()}
  defdelegate read(path), to: File

  @doc """
  Write a string to a file.

  ## Examples

      iex> AggregateLibrary.FileIO.write("output.txt", "content")
      :ok

      iex> AggregateLibrary.FileIO.write("/invalid/path.txt", "content")
      {:error, :enoent}
  """
  @spec write(Path.t(), iodata()) :: :ok | {:error, File.posix()}
  defdelegate write(path, content), to: File

  @doc """
  Write a string to a file, creating parent directories if needed.

  ## Examples

      iex> AggregateLibrary.FileIO.write!(path, content, mkdir: true)
      :ok
  """
  @spec write!(Path.t(), iodata(), keyword()) :: :ok | no_return()
  def write!(path, content, opts \\ []) do
    if Keyword.get(opts, :mkdir, false) do
      path |> Path.dirname() |> File.mkdir_p!()
    end

    File.write!(path, content)
  end

  @doc """
  Check if a file exists.

  ## Examples

      iex> AggregateLibrary.FileIO.exists?("test.txt")
      true

      iex> AggregateLibrary.FileIO.exists?("nonexistent.txt")
      false
  """
  @spec exists?(Path.t()) :: boolean()
  defdelegate exists?(path), to: File

  @doc """
  Check if a path is a directory.

  ## Examples

      iex> AggregateLibrary.FileIO.dir?("src/")
      true

      iex> AggregateLibrary.FileIO.dir?("file.txt")
      false
  """
  @spec dir?(Path.t()) :: boolean()
  defdelegate dir?(path), to: File

  @doc """
  List files in a directory.

  ## Examples

      iex> AggregateLibrary.FileIO.ls("src/")
      {:ok, ["file1.ex", "file2.ex"]}

      iex> AggregateLibrary.FileIO.ls("nonexistent/")
      {:error, :enoent}
  """
  @spec ls(Path.t()) :: {:ok, [binary()]} | {:error, File.posix()}
  defdelegate ls(path), to: File

  @doc """
  Remove a file.

  ## Examples

      iex> AggregateLibrary.FileIO.rm("temp.txt")
      :ok

      iex> AggregateLibrary.FileIO.rm("nonexistent.txt")
      {:error, :enoent}
  """
  @spec rm(Path.t()) :: :ok | {:error, File.posix()}
  defdelegate rm(path), to: File

  @doc """
  Remove a directory and all its contents recursively.

  ## Examples

      iex> AggregateLibrary.FileIO.rm_rf("temp_dir/")
      {:ok, ["temp_dir/file1.txt", "temp_dir/"]}
  """
  @spec rm_rf(Path.t()) :: {:ok, [binary()]} | {:error, File.posix(), binary()}
  defdelegate rm_rf(path), to: File

  @doc """
  Create a directory.

  ## Examples

      iex> AggregateLibrary.FileIO.mkdir("new_dir")
      :ok
  """
  @spec mkdir(Path.t()) :: :ok | {:error, File.posix()}
  defdelegate mkdir(path), to: File

  @doc """
  Create a directory and all parent directories.

  ## Examples

      iex> AggregateLibrary.FileIO.mkdir_p("a/b/c")
      :ok
  """
  @spec mkdir_p(Path.t()) :: :ok | {:error, File.posix()}
  defdelegate mkdir_p(path), to: File

  @doc """
  Copy a file or directory.

  ## Examples

      iex> AggregateLibrary.FileIO.cp("src.txt", "dest.txt")
      :ok
  """
  @spec cp(Path.t(), Path.t()) :: :ok | {:error, File.posix()}
  defdelegate cp(source, destination), to: File

  @doc """
  Copy a file or directory recursively.

  ## Examples

      iex> AggregateLibrary.FileIO.cp_r("src_dir/", "dest_dir/")
      {:ok, ["src_dir/file1.txt", "dest_dir/file1.txt"]}
  """
  @spec cp_r(Path.t(), Path.t()) :: {:ok, [binary()]} | {:error, File.posix(), binary()}
  defdelegate cp_r(source, destination), to: File

  @doc """
  Get file statistics.

  ## Examples

      iex> AggregateLibrary.FileIO.stat("file.txt")
      {:ok, %File.Stat{size: 1024, type: :regular, ...}}
  """
  @spec stat(Path.t()) :: {:ok, File.Stat.t()} | {:error, File.posix()}
  defdelegate stat(path), to: File

  @doc """
  Get file size in bytes.

  ## Examples

      iex> AggregateLibrary.FileIO.size("file.txt")
      {:ok, 1024}
  """
  @spec size(Path.t()) :: {:ok, non_neg_integer()} | {:error, File.posix()}
  def size(path) do
    case stat(path) do
      {:ok, %File.Stat{size: size}} -> {:ok, size}
      {:error, reason} -> {:error, reason}
    end
  end
end
