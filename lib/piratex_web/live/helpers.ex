defmodule PiratexWeb.Live.Helpers do
  def noreply(socket), do: {:noreply, socket}
  def ok(v), do: {:ok, v}
end
