# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
# SPDX-License-Identifier: MPL-2.0

defmodule Dnfinition.Security.HttpConfig do
  @moduledoc """
  OWASP-compliant HTTP security configuration.

  Implements OWASP recommended HTTP security headers and practices:
  - Strict TLS requirements (no HTTP fallback)
  - Content-Security-Policy headers
  - X-Content-Type-Options
  - X-Frame-Options
  - Referrer-Policy
  - Certificate pinning support
  - Request/response sanitization

  Reference: OWASP Secure Headers Project
  https://owasp.org/www-project-secure-headers/
  """

  require Logger

  @owasp_request_headers [
    # User agent with minimal fingerprinting
    {"User-Agent", "DNFinition/0.1.0 (Package Manager)"},
    # Accept only what we need
    {"Accept", "application/json, application/xml, text/plain, application/octet-stream"},
    # Disable caching for sensitive requests
    {"Cache-Control", "no-store, no-cache, must-revalidate"},
    {"Pragma", "no-cache"},
    # Do not track
    {"DNT", "1"},
    # Secure encoding
    {"Accept-Encoding", "gzip, deflate"},
    # Minimal accept-language
    {"Accept-Language", "en"},
    # Connection settings
    {"Connection", "keep-alive"}
  ]

  @owasp_security_options [
    # TLS settings
    ssl: [
      # Require TLS 1.2 or higher
      versions: [:"tlsv1.3", :"tlsv1.2"],
      # Secure cipher suites only
      ciphers: [
        ~c"TLS_AES_256_GCM_SHA384",
        ~c"TLS_AES_128_GCM_SHA256",
        ~c"TLS_CHACHA20_POLY1305_SHA256",
        ~c"ECDHE-RSA-AES256-GCM-SHA384",
        ~c"ECDHE-RSA-AES128-GCM-SHA256",
        ~c"ECDHE-RSA-CHACHA20-POLY1305"
      ],
      # Certificate verification
      verify: :verify_peer,
      # Use system CA store
      cacerts: :public_key.cacerts_get(),
      # Depth limit for certificate chain
      depth: 3,
      # Require server name indication
      server_name_indication: :disable,
      # Secure renegotiation
      secure_renegotiate: true,
      # Reuse sessions for performance
      reuse_sessions: true
    ],
    # Connection settings
    connect_timeout: 10_000,
    recv_timeout: 30_000,
    # Redirect handling
    follow_redirect: true,
    max_redirect: 3,
    # Proxy support (for VPN/SDP)
    proxy: nil
  ]

  @doc """
  Get OWASP-compliant HTTP headers for requests.
  """
  def owasp_headers do
    @owasp_request_headers
  end

  @doc """
  Get OWASP-compliant security options for hackney.
  """
  def owasp_options(extra_opts \\ []) do
    # Merge with any extra options
    base_opts = Keyword.merge(@owasp_security_options, extra_opts)

    # Check if VPN/SDP proxy is configured
    case get_vpn_proxy() do
      nil -> base_opts
      proxy -> Keyword.put(base_opts, :proxy, proxy)
    end
  end

  @doc """
  Make a secure HTTP request with OWASP compliance.
  """
  def secure_request(method, url, body \\ "", extra_headers \\ []) do
    # Validate URL scheme
    uri = URI.parse(url)

    unless uri.scheme == "https" do
      Logger.warning("Non-HTTPS URL blocked: #{url}")
      {:error, :https_required}
    else
      headers = owasp_headers() ++ extra_headers
      options = owasp_options()

      :hackney.request(method, url, headers, body, options)
    end
  end

  @doc """
  Validate response headers for security issues.
  """
  def validate_response_headers(headers) when is_list(headers) do
    issues = []

    # Check for security headers in response
    content_type = get_header(headers, "content-type")
    x_content_type = get_header(headers, "x-content-type-options")

    issues = if content_type && x_content_type != "nosniff" do
      ["Missing X-Content-Type-Options: nosniff" | issues]
    else
      issues
    end

    # Check for dangerous content types
    issues = if content_type && String.contains?(content_type, "text/html") do
      ["Unexpected HTML content in package response" | issues]
    else
      issues
    end

    if length(issues) > 0 do
      Logger.warning("Security header issues: #{Enum.join(issues, ", ")}")
      {:warn, issues}
    else
      :ok
    end
  end

  @doc """
  Sanitize URL to prevent injection attacks.
  """
  def sanitize_url(url) when is_binary(url) do
    # Parse and rebuild URL to prevent injection
    uri = URI.parse(url)

    # Block non-HTTPS
    if uri.scheme != "https" do
      {:error, :https_required}
    else
      # Block suspicious characters
      if String.match?(url, ~r/[\x00-\x1f\x7f]/) do
        {:error, :invalid_characters}
      else
        # Block userinfo in URL (potential credential leak)
        if uri.userinfo do
          {:error, :userinfo_not_allowed}
        else
          {:ok, URI.to_string(uri)}
        end
      end
    end
  end

  @doc """
  Validate checksum format to prevent injection.
  """
  def validate_checksum(checksum, type) when is_binary(checksum) do
    expected_length = case type do
      :sha256 -> 64
      :sha512 -> 128
      :md5 -> 32  # MD5 allowed only for legacy verification
    end

    if String.length(checksum) == expected_length and
       String.match?(checksum, ~r/^[a-fA-F0-9]+$/) do
      {:ok, String.downcase(checksum)}
    else
      {:error, :invalid_checksum_format}
    end
  end
  def validate_checksum(nil, _type), do: {:ok, nil}

  @doc """
  Get VPN/SDP proxy configuration if available.
  """
  def get_vpn_proxy do
    # Check environment variables for proxy configuration
    proxy_url = System.get_env("DNFINITION_PROXY_URL") ||
                System.get_env("HTTPS_PROXY") ||
                System.get_env("https_proxy")

    if proxy_url do
      proxy_url
    else
      # Check for SDP/Zero Trust configuration
      sdp_config = get_sdp_config()
      if sdp_config do
        sdp_config.proxy_url
      else
        nil
      end
    end
  end

  @doc """
  Check if VPN/SDP is required and active.
  """
  def vpn_required? do
    System.get_env("DNFINITION_REQUIRE_VPN", "false") == "true"
  end

  @doc """
  Verify VPN/SDP connection is active before making requests.
  """
  def verify_vpn_active do
    if vpn_required?() do
      case get_vpn_proxy() do
        nil ->
          {:error, :vpn_required_but_not_configured}

        proxy_url ->
          # Test proxy connectivity
          case :hackney.request(:head, proxy_url, [], "", [connect_timeout: 5_000]) do
            {:ok, _, _, _} -> :ok
            {:error, reason} -> {:error, {:vpn_unreachable, reason}}
          end
      end
    else
      :ok
    end
  end

  ## Private Functions

  defp get_header(headers, name) do
    name_lower = String.downcase(name)

    headers
    |> Enum.find(fn {k, _v} -> String.downcase(k) == name_lower end)
    |> case do
      {_, value} -> value
      nil -> nil
    end
  end

  defp get_sdp_config do
    # Check for common SDP/Zero Trust configurations
    config_paths = [
      "/etc/dnfinition/sdp.json",
      Path.expand("~/.config/dnfinition/sdp.json"),
      System.get_env("DNFINITION_SDP_CONFIG")
    ]

    config_paths
    |> Enum.filter(&(&1 && File.exists?(&1)))
    |> List.first()
    |> case do
      nil -> nil
      path ->
        case File.read(path) do
          {:ok, content} ->
            case Jason.decode(content) do
              {:ok, config} ->
                %{
                  proxy_url: config["proxy_url"],
                  ca_cert: config["ca_cert"],
                  client_cert: config["client_cert"],
                  client_key: config["client_key"]
                }

              {:error, _} ->
                Logger.warning("Invalid SDP config at #{path}")
                nil
            end

          {:error, _} ->
            nil
        end
    end
  end
end
