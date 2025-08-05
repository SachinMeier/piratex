defmodule PiratexWeb.Live.Controls do
  use PiratexWeb, :live_view

  import PiratexWeb.Live.Helpers
  import PiratexWeb.Components.PiratexComponents

  # TODO: this is very rudimentary. do real auth
  @password_hash Base.decode16!("623500fe9c1b827b078b9e4d4d23d831037aa9edc91c1037a73da7c5171ba9e7", case: :lower)

  @configs %{
    turn_timeout_ms: :integer,
    # time for players to vote on a challenge
    challenge_timeout_ms: :integer,

    # time for the first player to join
    new_game_timeout_ms: :integer,
    # games timeout after inactivity
    game_timeout_ms: :integer,
    # ms at the end of game for claims
    end_game_time_ms: :integer,

    # min and max player name length
    min_player_name: :integer,
    max_player_name: :integer,

    # min word length
    min_word_length: :integer,

    # max number of players
    max_players: :integer
  }

  # TODO: move this to a session to stay logged in
  def mount(_params, _session, socket) do
    socket
    |> assign(auth: false)
    |> assign_config_values()
    |> ok()
  end

  def assign_config_values(socket) do
    configs =
      @configs
      |> Enum.map(fn {cfg, type} ->
        {cfg, {type, Application.get_env(:piratex, cfg)}}
      end)

    assign(socket, configs: configs)
  end

  def render(%{auth: true} = assigns) do
    ~H"""
    <div class="flex flex-wrap justify-between gap-4 max-w-96">
      <%= for {cfg, {type, value}} <- @configs do %>
        <div class="flex flex-col max-w-48">
          <div>
            <%= cfg %>
          </div>
          <.form
            for={%{}}
            phx-submit="update_config"
            class="flex flex-row gap-2 mx-auto max-w-48"
          >
            <input type="hidden" name={"config"} field="config_name" value={cfg}>
            <.ps_text_input
              id={"controls_input_#{cfg}"}
              name="value"
              field="config_value"
              placeholder={value}
              type={type}
            />
            <.ps_button type="submit">
              <div phx-disable-with="Validating..." class="select-none">UPDATE</div>
            </.ps_button>
          </.form>
        </div>
      <% end %>
    </div>
    """
  end

  def render(%{auth: false} = assigns) do
    ~H"""
    <div class="mx-auto">
      <.form
        for={%{}}
        phx-submit="enter_password"
        class="flex flex-col gap-2 mx-auto max-w-48"
      >
        <.ps_text_input
          id="controls_password_input"
          name="password"
          field={:password}
          placeholder="Password"
          type={"password"}
        />
        <.ps_button type="submit">
          <div phx-disable-with="Validating..." class="select-none">ENTER</div>
        </.ps_button>
      </.form>
    </div>
    """
  end

  def handle_event("enter_password", %{"password" => password}, socket) do
    password_hash =
      password
      |> String.trim()
      |> then(&:crypto.hash(:sha256, &1))

    if password_hash == @password_hash do
      socket
      |> assign(auth: true)
      |> noreply()
    else
      socket
      |> put_flash(:error, "incorrect")
      |> noreply()
    end
  end

  def handle_event("update_config", %{"config" => config, "value" => value}, socket) do
    with {:ok, {cfg, value}} <- parse_config_update(config, value),
        :ok <- Application.put_env(:piratex, cfg, value)  do
           {:noreply, assign_config_values(socket)}
    else
      {:error, reason} ->
        socket
        |> put_flash(:error, "update failed: #{reason}")
        |> noreply()

      _ ->
        socket
        |> put_flash(:error, "update failed")
        |> noreply()
    end
  end

  @spec parse_config_update(String.t(), String.t()) :: {:ok, {atom(), any()}} | {:error, String.t()}
  defp parse_config_update(cfg, value) do
    cfg = String.to_existing_atom(cfg)

    case Map.get(@configs, cfg, nil) do
      nil ->
        {:error, "empty value"}
      :string ->
        {:ok, {cfg, String.trim(value)}}

      :integer ->
        case Integer.parse(value) do
          {value, ""} -> {:ok, {cfg, value}}
          _ -> {:error, "invalid entry"}
        end
    end
  end
end
