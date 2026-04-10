defmodule PiratexWeb.Protocol do
  @moduledoc """
  Wire-protocol version for the TUI channel and HTTP API.

  Semantics (see TUI_PLAN.md §3.7):

  * **Major** is a hard compatibility gate. A client with a different major than
    the server cannot play and is shown an upgrade prompt.
  * **Minor** is a soft hint. A client with a lower minor keeps working, with
    an "upgrade available" notice.

  Bump major for removed/renamed events, removed/renamed fields, changed field
  types, or changed required payload shape. Bump minor for additive,
  backward-compatible changes (new optional field, new error atom).
  """

  @major 1
  @minor 0

  @spec major() :: non_neg_integer()
  def major, do: @major

  @spec minor() :: non_neg_integer()
  def minor, do: @minor

  @spec version() :: {non_neg_integer(), non_neg_integer()}
  def version, do: {@major, @minor}

  @spec version_string() :: String.t()
  def version_string, do: "#{@major}.#{@minor}"

  @type compatibility :: :ok | :minor_behind | :client_outdated | :server_outdated

  @doc """
  Compares a client's major/minor against the server's.
  """
  @spec compare(non_neg_integer(), non_neg_integer()) :: compatibility()
  def compare(client_major, _client_minor) when client_major < @major, do: :client_outdated
  def compare(client_major, _client_minor) when client_major > @major, do: :server_outdated
  def compare(_client_major, client_minor) when client_minor < @minor, do: :minor_behind
  def compare(_client_major, _client_minor), do: :ok

  @doc """
  Upgrade URL surfaced in protocol-mismatch responses.
  """
  @spec upgrade_url() :: String.t()
  def upgrade_url, do: "https://github.com/SachinMeier/piratex/releases/latest"
end
