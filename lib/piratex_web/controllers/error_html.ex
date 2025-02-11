defmodule PiratexWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use PiratexWeb, :html

  import PiratexWeb.Components.PiratexComponents

  # If you want to customize your error pages,
  # uncomment the embed_templates/1 call below
  # and add pages to the error directory:
  #
  #   * lib/piratex_web/controllers/error_html/404.html.heex
  #   * lib/piratex_web/controllers/error_html/500.html.heex
  #
  embed_templates "error_html/*"
end
