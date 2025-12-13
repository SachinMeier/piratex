defmodule PiratexWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use PiratexWeb, :controller` and
  `use PiratexWeb, :live_view`.
  """
  use PiratexWeb, :html

  import PiratexWeb.Components.PiratexComponents
  import PiratexWeb.Components.DarkModeToggle

  embed_templates "layouts/*"

  def get_og_title(assigns) do
    assigns[:og_title] ||
      (assigns[:seo_metadata] && assigns[:seo_metadata][:og_title]) ||
      assigns[:page_title] ||
      "Pirate Scrabble - Online Word Game"
  end

  def get_og_description(assigns) do
    assigns[:og_description] ||
      (assigns[:seo_metadata] && assigns[:seo_metadata][:og_description]) ||
      assigns[:page_description] ||
      "Play Pirate Scrabble!"
  end

  def get_og_image(assigns) do
    assigns[:og_image] ||
      (assigns[:seo_metadata] && assigns[:seo_metadata][:og_image]) ||
      "https://piratescrabble.com/images/logo.png"
  end

  def get_twitter_title(assigns) do
    assigns[:twitter_title] ||
      (assigns[:seo_metadata] && assigns[:seo_metadata][:twitter_title]) ||
      assigns[:page_title] ||
      "Pirate Scrabble - Online Word Game"
  end

  def get_twitter_description(assigns) do
    assigns[:twitter_description] ||
      (assigns[:seo_metadata] && assigns[:seo_metadata][:twitter_description]) ||
      assigns[:page_description] ||
      "Play Pirate Scrabble!"
  end

  def get_twitter_image(assigns) do
    assigns[:twitter_image] ||
      (assigns[:seo_metadata] && assigns[:seo_metadata][:twitter_image]) ||
      "https://piratescrabble.com/images/logo.png"
  end
end
