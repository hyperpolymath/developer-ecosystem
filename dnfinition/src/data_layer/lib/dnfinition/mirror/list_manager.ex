# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule Dnfinition.Mirror.ListManager do
  @moduledoc """
  Manage mirror lists for different package managers.

  Supports parsing and generating mirror lists for:
  - DNF/Yum (metalink files, .repo files)
  - APT (sources.list)
  - Pacman (mirrorlist)
  - Zypper (repositories)

  Security:
  - OWASP-compliant HTTP headers for all network requests
  - URL sanitization and validation
  - TLS 1.2+ enforcement
  """

  require Logger

  alias Dnfinition.Security.HttpConfig

  @type pm_type :: :dnf | :apt | :pacman | :zypper | :brew

  @type mirror_entry :: %{
    url: String.t(),
    name: String.t() | nil,
    enabled: boolean(),
    country: String.t() | nil,
    protocol: :https | :http | :ftp,
    priority: integer()
  }

  ## DNF/Yum

  @doc """
  Parse DNF/Yum repo file content.
  Returns list of repositories with their mirrors.
  """
  def parse_dnf_repo(content) when is_binary(content) do
    content
    |> String.split(~r/\[([^\]]+)\]/)
    |> Enum.chunk_every(2)
    |> Enum.flat_map(fn
      [name, body] ->
        mirrors = extract_dnf_mirrors(body)
        if length(mirrors) > 0 do
          [%{name: String.trim(name), mirrors: mirrors, enabled: not String.contains?(body, "enabled=0")}]
        else
          []
        end
      _ ->
        []
    end)
  end

  defp extract_dnf_mirrors(body) do
    # Look for baseurl or mirrorlist
    cond do
      String.contains?(body, "baseurl=") ->
        body
        |> String.split("\n")
        |> Enum.filter(&String.contains?(&1, "baseurl="))
        |> Enum.flat_map(fn line ->
          line
          |> String.split("baseurl=")
          |> Enum.drop(1)
          |> Enum.map(&String.trim/1)
          |> Enum.map(&parse_url_to_entry/1)
        end)

      String.contains?(body, "metalink=") or String.contains?(body, "mirrorlist=") ->
        # Would need to fetch the metalink/mirrorlist URL
        []

      true ->
        []
    end
  end

  @doc """
  Fetch and parse DNF metalink file.

  Uses OWASP-compliant HTTP security headers and validates URL.
  """
  def fetch_dnf_metalink(url) do
    # Validate URL for OWASP compliance
    case HttpConfig.sanitize_url(url) do
      {:ok, safe_url} ->
        do_fetch_metalink(safe_url)

      {:error, reason} ->
        Logger.warning("URL validation failed for metalink fetch: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp do_fetch_metalink(url) do
    # Use OWASP-compliant headers and options
    headers = HttpConfig.owasp_headers()
    options = HttpConfig.owasp_options([recv_timeout: 10_000])

    case :hackney.request(:get, url, headers, "", options) do
      {:ok, 200, response_headers, ref} ->
        # Validate response headers for security issues
        HttpConfig.validate_response_headers(response_headers)

        case :hackney.body(ref) do
          {:ok, body} ->
            parse_metalink(body)

          {:error, reason} ->
            {:error, reason}
        end

      {:ok, status, _headers, ref} ->
        :hackney.skip_body(ref)
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_metalink(xml_content) do
    # Simple regex-based XML parsing for metalink
    mirrors = Regex.scan(~r/<url[^>]*protocol="(https?|ftp)"[^>]*>([^<]+)<\/url>/, xml_content)
      |> Enum.map(fn [_, protocol, url] ->
        parse_url_to_entry(url, String.to_atom(protocol))
      end)

    {:ok, mirrors}
  end

  ## APT

  @doc """
  Parse APT sources.list content.
  """
  def parse_apt_sources(content) when is_binary(content) do
    content
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
    |> Enum.map(&parse_apt_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_apt_line(line) do
    case String.split(line, " ", parts: 4) do
      [type, url | rest] when type in ["deb", "deb-src"] ->
        %{
          type: String.to_atom(type),
          url: url,
          components: rest,
          enabled: true
        }

      _ ->
        nil
    end
  end

  @doc """
  Generate APT sources.list entry.
  """
  def generate_apt_entry(url, dist, components, opts \\ []) do
    type = if opts[:source], do: "deb-src", else: "deb"
    "#{type} #{url} #{dist} #{Enum.join(components, " ")}"
  end

  ## Pacman

  @doc """
  Parse Pacman mirrorlist content.
  """
  def parse_pacman_mirrorlist(content) when is_binary(content) do
    content
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&parse_pacman_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_pacman_line(line) do
    cond do
      String.starts_with?(line, "#Server") ->
        # Commented out mirror
        url = line |> String.replace("#Server = ", "") |> String.trim()
        entry = parse_url_to_entry(url)
        %{entry | enabled: false}

      String.starts_with?(line, "Server") ->
        # Active mirror
        url = line |> String.replace("Server = ", "") |> String.trim()
        parse_url_to_entry(url)

      String.starts_with?(line, "## ") ->
        # Country header (e.g., "## Germany")
        nil

      true ->
        nil
    end
  end

  @doc """
  Generate Pacman mirrorlist content.
  """
  def generate_pacman_mirrorlist(mirrors) when is_list(mirrors) do
    mirrors
    |> Enum.map(fn mirror ->
      if mirror.enabled do
        "Server = #{mirror.url}"
      else
        "#Server = #{mirror.url}"
      end
    end)
    |> Enum.join("\n")
  end

  ## Zypper

  @doc """
  Parse Zypper repo file content.
  """
  def parse_zypper_repo(content) when is_binary(content) do
    # Zypper repo format is similar to DNF
    parse_dnf_repo(content)
  end

  ## Common Functions

  @doc """
  Get mirror list for a specific package manager.
  Returns URLs suitable for optimization.
  """
  def get_mirrors_for_pm(pm_type) do
    case pm_type do
      :dnf ->
        get_dnf_mirrors()

      :apt ->
        get_apt_mirrors()

      :pacman ->
        get_pacman_mirrors()

      :zypper ->
        get_zypper_mirrors()

      _ ->
        {:error, :unsupported_pm}
    end
  end

  defp get_dnf_mirrors do
    # Read from /etc/yum.repos.d/
    repo_dir = "/etc/yum.repos.d"

    if File.dir?(repo_dir) do
      mirrors = repo_dir
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".repo"))
        |> Enum.flat_map(fn file ->
          path = Path.join(repo_dir, file)
          case File.read(path) do
            {:ok, content} ->
              repos = parse_dnf_repo(content)
              Enum.flat_map(repos, fn repo ->
                if repo.enabled do
                  Enum.map(repo.mirrors, & &1.url)
                else
                  []
                end
              end)

            {:error, _} ->
              []
          end
        end)
        |> Enum.uniq()

      {:ok, mirrors}
    else
      {:error, :not_found}
    end
  end

  defp get_apt_mirrors do
    sources_list = "/etc/apt/sources.list"

    if File.exists?(sources_list) do
      case File.read(sources_list) do
        {:ok, content} ->
          entries = parse_apt_sources(content)
          mirrors = entries
            |> Enum.filter(&(&1.type == :deb))
            |> Enum.map(& &1.url)
            |> Enum.uniq()

          {:ok, mirrors}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :not_found}
    end
  end

  defp get_pacman_mirrors do
    mirrorlist = "/etc/pacman.d/mirrorlist"

    if File.exists?(mirrorlist) do
      case File.read(mirrorlist) do
        {:ok, content} ->
          entries = parse_pacman_mirrorlist(content)
          mirrors = entries
            |> Enum.filter(& &1.enabled)
            |> Enum.map(& &1.url)

          {:ok, mirrors}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :not_found}
    end
  end

  defp get_zypper_mirrors do
    repo_dir = "/etc/zypp/repos.d"

    if File.dir?(repo_dir) do
      mirrors = repo_dir
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".repo"))
        |> Enum.flat_map(fn file ->
          path = Path.join(repo_dir, file)
          case File.read(path) do
            {:ok, content} ->
              repos = parse_zypper_repo(content)
              Enum.flat_map(repos, fn repo ->
                if repo.enabled do
                  Enum.map(repo.mirrors, & &1.url)
                else
                  []
                end
              end)

            {:error, _} ->
              []
          end
        end)
        |> Enum.uniq()

      {:ok, mirrors}
    else
      {:error, :not_found}
    end
  end

  defp parse_url_to_entry(url, protocol \\ nil) do
    uri = URI.parse(url)
    detected_protocol = protocol || String.to_atom(uri.scheme || "https")

    %{
      url: url,
      name: uri.host,
      enabled: true,
      country: extract_country_from_url(url),
      protocol: detected_protocol,
      priority: if(detected_protocol == :https, do: 1, else: 2)
    }
  end

  defp extract_country_from_url(url) do
    uri = URI.parse(url)
    host = uri.host || ""

    cond do
      String.contains?(host, ".de.") or String.ends_with?(host, ".de") -> "DE"
      String.contains?(host, ".us.") or String.ends_with?(host, ".us") -> "US"
      String.contains?(host, ".uk.") or String.ends_with?(host, ".uk") -> "UK"
      String.contains?(host, ".fr.") or String.ends_with?(host, ".fr") -> "FR"
      String.contains?(host, ".nl.") or String.ends_with?(host, ".nl") -> "NL"
      String.contains?(host, ".se.") or String.ends_with?(host, ".se") -> "SE"
      String.contains?(host, ".jp.") or String.ends_with?(host, ".jp") -> "JP"
      String.contains?(host, ".au.") or String.ends_with?(host, ".au") -> "AU"
      String.contains?(host, ".ca.") or String.ends_with?(host, ".ca") -> "CA"
      true -> nil
    end
  end
end
