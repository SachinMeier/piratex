defmodule PiratexWeb.ProtocolVersionTest do
  @moduledoc """
  Pinned snapshot of the wire protocol version. If this test fails, update
  **both** the server constant (lib/piratex_web/protocol.ex) and the TUI
  constant (clients/tui/src/contract.ts) in a coordinated release, then
  update this snapshot. See TUI_PLAN.md §3.7 and §7.9.
  """

  use ExUnit.Case, async: true

  alias PiratexWeb.Protocol

  @expected_major 1
  @expected_minor 0

  test "protocol major is pinned" do
    assert Protocol.major() == @expected_major
  end

  test "protocol minor is pinned" do
    assert Protocol.minor() == @expected_minor
  end

  test "version_string reflects both" do
    assert Protocol.version_string() == "#{@expected_major}.#{@expected_minor}"
  end

  describe "compare/2" do
    test "returns :ok for exact match" do
      assert Protocol.compare(@expected_major, @expected_minor) == :ok
    end

    test "returns :client_outdated for older major" do
      assert Protocol.compare(@expected_major - 1, @expected_minor) == :client_outdated
    end

    test "returns :server_outdated for newer major" do
      assert Protocol.compare(@expected_major + 1, @expected_minor) == :server_outdated
    end

    test "returns :minor_behind for older minor" do
      assert Protocol.compare(@expected_major, @expected_minor - 1) == :minor_behind
    end
  end
end
