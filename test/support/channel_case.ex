defmodule PiratexWeb.ChannelCase do
  @moduledoc """
  Test case helper for `Phoenix.Channel` tests against `PiratexWeb.GameChannel`.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import PiratexWeb.ChannelCase

      @endpoint PiratexWeb.Endpoint
    end
  end
end
