defmodule PiratexWeb.Live.GameLive do
  use PiratexWeb, :live_view

  import PiratexWeb.Components.PiratexComponents

  alias Piratex.Game
  alias Piratex.GameHelpers

  def mount(_params, _session, socket) do
    # this is set in GameSession.on_mount
    player_name = socket.assigns.player_name
    # TODO: we currently only store the game_id, not the pid,
    # so we need to lookup the pid every time we send any message or remount
    game_id = socket.assigns.game_id
    game_state = Game.get_state(game_id)
    my_turn_idx = determine_my_turn_idx(player_name, game_state)

    Phoenix.PubSub.subscribe(Piratex.PubSub, Game.events_topic(game_id))

    socket =
      socket
      |> assign(
        my_turn_idx: my_turn_idx,
        game_id: game_id,
        game_state: game_state,
        word_form: to_form(%{"word" => ""}),
        visible_word_steal: nil,
        game_progress_bar: game_state.status == :playing,
        letter_pool_size: GameHelpers.letter_pool_size(),
        min_word_length: Piratex.Services.WordClaimService.min_word_length()
      )

    {:ok, set_page_title(socket)}
  end

  def render(assigns) do
    ~H"""
    <%= case @game_state.status do %>
      <% :waiting -> %>
        <.render_waiting {assigns} />
      <% :playing -> %>
        <.render_playing {assigns} />
      <% :finished -> %>
        <.render_finished {assigns} />
    <% end %>
    """
  end

  attr :game_state, :map, required: true

  def render_waiting(assigns) do
    ~H"""
    <div class="flex flex-col mx-auto justify-around">
      <div class="mx-auto">
        <.tile_word word="players" />
      </div>

      <div class="my-4 mx-auto">
        <ul class="list-decimal my-4">
          <%= for %{name: player_name} <- @game_state.players do %>
            <li><%= player_name %></li>
          <% end %>
        </ul>
      </div>

      <div class="mx-auto">
        <.ps_button phx_click="start_game">
          START
        </.ps_button>
      </div>

      <div class="mt-4 mx-auto">
        <.ps_button phx_click="leave_waiting_game">
          QUIT
        </.ps_button>
      </div>
    </div>
    """
  end

  attr :game_state, :map, required: true

  def render_finished(assigns) do
    assigns = assign(assigns, ranked_players: rank_players(assigns.game_state.players))

    ~H"""
    <div class="flex flex-col w-full mx-auto items-center">
      <div class="mb-4">
        <.tile_word word="game over" />
      </div>

      <div class="flex flex-col">
        <%= for {rank, player} <- @ranked_players do %>
          <div class="my-2">
            <.render_podium_player player={player} rank={rank} />
          </div>
        <% end %>
      </div>

      <div class="flex flex-col">
        <.ps_button phx_click="quit_game">
          QUIT
        </.ps_button>
      </div>
    </div>
    """
  end

  attr :game_state, :map, required: true
  attr :my_turn_idx, :integer, required: true
  attr :word_value, :string, required: true

  def render_playing(assigns) do
    ~H"""
    <div class="flex flex-col">
      <div id="board_center_and_actions" class="flex flex-col md:flex-row gap-8">
        <.render_center center={@game_state.center} />

        <.render_player_action_area
          game_state={@game_state}
          word_form={@word_form}
          min_word_length={@min_word_length}
          is_turn={@my_turn_idx == @game_state.turn}
          paused={@game_state.challenges != []}
        />
      </div>

      <div id="board" class="flex flex-col md:flex-row justify-between w-full mt-8">
        <div id="board_players" class="flex flex-wrap gap-4">
          <%= for player <- @game_state.players do %>
            <.render_player_word_area player={player} />
          <% end %>
        </div>
        <.render_history game_state={@game_state} paused={@game_state.challenges != []} />
      </div>
    </div>
    <.render_modal {assigns} />
    """
  end

  attr :center, :list, required: true

  defp render_center(assigns) do
    # border-2 border-black dark:border-white
    ~H"""
    <div id="board_center" class="flex flex-wrap gap-x-2 gap-y-2 w-full max-h-52 overflow-y-auto overscroll-contain no-scrollbar rounded-md p-4">
      <%= for letter <- @center do %>
        <div class="md:my-0">
          <.tile letter={letter} />
        </div>
      <% end %>
    </div>
    """
  end

  attr :player, :map, required: true

  defp render_player_word_area(assigns) do
    ~H"""
    <div id={"board_player_#{@player.name}"} class="flex flex-col min-w-48 rounded-md border-2 border-black dark:border-white min-h-48">
      <div class="w-full px-auto text-center border-b-2 border-black dark:border-white">
        <%= @player.name %><%= if @player.status == :quit do %> (QUIT)<% end %>
      </div>
      <div class="flex flex-col h-full mx-2 mb-2 overflow-x-auto overscroll-contain no-scrollbar">
        <%= for word <- @player.words do %>
          <div class="mt-2">
            <.tile_word word={word} />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr :player, :map, required: true
  attr :rank, :integer, required: true

  defp render_podium_player(assigns) do
    ~H"""
    <div id={"board_player_#{@player.name}"} class="flex flex-col min-w-48 rounded-md border-2 border-black dark:border-white min-h-48">
      <div class="w-full px-auto text-center border-b-2 border-black dark:border-white">
        <%= @rank %>. <%= @player.name %> (<%= @player.score %>)
      </div>
      <div class="flex flex-col mx-2 mb-2">
        <%= for word <- @player.words do %>
          <div class="mt-2">
            <.tile_word word={word} />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # attr :is_turn, :boolean, required: true

  defp render_player_action_area(assigns) do
    # TODO: maybe make the text input and submit a component with merged borders.
    ~H"""
    <div id="actions_area" class="flex flex-col">
      <div class="flex flex-row md:flex-col gap-4">
        <.form for={@word_form}  phx-submit="submit_new_word" phx-change="word_change" class="flex flex-row">
          <.ps_text_input
            id="new_word_input"
            name="word"
            form={@word_form}
            field={:word}
            placeholder="New Word"
            class="rounded-r-none"
          />
          <.ps_button type="submit" class="rounded-l-none border-l-0" disabled={@paused}>
            SUBMIT
          </.ps_button>
        </.form>
        <div class="w-full mx-auto">
          <.ps_button class="w-full max-w-xs mx-auto" phx_click="flip_letter" phx_disable_with="Flipping..." disabled={@game_state.letter_pool == [] || !@is_turn || @paused}>
            <%= cond do %>
              <% @game_state.letter_pool == [] -> %>
                Game Over
              <% @is_turn -> %>
                FLIP
              <% true -> %>
                <div class="hidden md:block">
                  <%= Enum.at(@game_state.players, @game_state.turn).name %>'s turn
                </div>
                <div class="block md:hidden">
                  FLIP
                </div>
            <% end %>
          </.ps_button>
        </div>
        <div class="hidden sm:block w-full mx-auto">
          <.ps_button class="w-full max-w-xs mx-auto" phx_click="quit_game" data_confirm="Are you sure you want to quit?">
            QUIT
          </.ps_button>
        </div>
      </div>
    </div>
    """
  end

  defp render_history(assigns) do
    ~H"""
    <div class="flex flex-col px-4 mt-4 md:mt-0">
      <div class="mb-4">
        <.tile_word word="History" />
      </div>
      <%= for %{thief_word: thief_word} = word_steal <- Enum.take(@game_state.history, 3) do %>
        <div class="flex flex-row justify-between mt-2">
          <button class="flex flex-row" phx-click="show_word_steal" phx-value-word={thief_word}>
            <%= if String.length(thief_word) > 5 do %>
              <.tile_word word={String.slice(thief_word, 0, 5)} />
              <.ellipsis />
            <% else %>
              <.tile_word word={thief_word} />
            <% end %>
          </button>

          <.render_challenge_word_button
            :if={GameHelpers.word_in_play?(@game_state, thief_word) and !GameHelpers.word_steal_has_been_challenged?(@game_state, word_steal)}
            word={thief_word}
            paused={@paused}
          />
        </div>
      <% end %>
    </div>
    """
  end

  defp render_challenge_word_button(assigns) do
    ~H"""
    <.link href="#" phx-click="challenge_word" phx-value-word={@word}>
      <.tile letter="X" />
    </.link>
    """
  end

  defp render_modal(assigns) do
    ~H"""
    <%= cond do %>
      <% @game_state.challenges != [] -> %>
        <.ps_modal title="challenge">
          <.render_challenge challenge={Enum.at(@game_state.challenges, 0)} player_name={@player_name} />
        </.ps_modal>
      <% @visible_word_steal != nil -> %>
        <.ps_modal title="word steal">
          <.render_word_steal word_steal={@visible_word_steal} />
        </.ps_modal>
      <% true -> %>
    <% end %>
    """
  end

  defp render_challenge(assigns) do
    ~H"""
    <div class="flex flex-col gap-2">
      <%= if @challenge.word_steal.victim_word do %>
        Old Word:
        <.tile_word word={@challenge.word_steal.victim_word} />
        New Word:
      <% end %>
      <.tile_word word={@challenge.word_steal.thief_word} />
    </div>
    <%= if has_voted?(@challenge, @player_name) do %>
      Waiting for other players to vote...
    <% else %>
      <div class="flex flex-row w-full justify-around">
        <.ps_button phx_click="accept_steal" phx-value-challenge_id={@challenge.id}>
          VALID
        </.ps_button>
        <.ps_button phx_click="reject_steal" phx-value-challenge_id={@challenge.id}>
          INVALID
        </.ps_button>
      </div>
    <% end %>
    """
  end

  defp render_word_steal(assigns) do
    ~H"""
    <div class="flex flex-col gap-2">
      <%= if @word_steal.victim_word do %>
        Old Word:
        <.tile_word word={@word_steal.victim_word} />
        New Word:
      <% else %>
        Word:
      <% end %>
      <.tile_word word={@word_steal.thief_word} />
      <div class="mt-4 mx-auto">
        <.ps_button phx-click="hide_word_steal">
          DONE
        </.ps_button>
      </div>
    </div>
    """
  end

  # EVENT HANDLING

  def handle_event("start_game", _params, socket) do
    Game.start_game(socket.assigns.game_id, socket.assigns.player_token)
    {:noreply, socket}
  end

  def handle_event("submit_new_word", %{"word" => word}, %{assigns: %{min_word_length: min_word_length}} = socket) do
    if String.length(word) < min_word_length do
      {:noreply, reset_word_form(socket)}
    else
      socket =
        case Game.claim_word(socket.assigns.game_id, socket.assigns.player_token, String.downcase(word)) do
          :ok ->
            socket
          {:error, error} ->
            put_flash(socket, :error, error)
        end

      {:noreply, reset_word_form(socket)}
      end
  end

  # I don't know why this is needed to reset the word after submit, but it is
  def handle_event("word_change", %{"word" => word}, socket) do
    socket = assign(socket, word_form: to_form(%{"word" => word}))
    {:noreply, socket}
  end

  def handle_event("flip_letter", _params, %{assigns: %{player_token: player_token}} = socket) do
    # Don't allow flipping if there are challenges pending
    if socket.assigns.game_state.challenges == [] do
      Game.flip_letter(socket.assigns.game_id, player_token)
    end
    {:noreply, socket}
  end

  def handle_event("show_word_steal", %{"word" => word_steal}, socket) do
    word_steal = Piratex.Services.ChallengeService.find_word_steal(socket.assigns.game_state, word_steal)
    {:noreply, assign(socket, visible_word_steal: word_steal)}
  end

  def handle_event("hide_word_steal", _params, socket) do
    {:noreply, assign(socket, visible_word_steal: nil)}
  end

  def handle_event("challenge_word", %{"word" => word}, %{assigns: %{player_token: player_token}} = socket) do
    Game.challenge_word(socket.assigns.game_id, player_token, word)
    {:noreply, socket}
  end

  def handle_event("accept_steal", %{"challenge_id" => challenge_id}, %{assigns: %{player_token: player_token}} = socket) do
    Game.challenge_vote(socket.assigns.game_id, player_token, String.to_integer(challenge_id), true)
    {:noreply, socket}
  end

  def handle_event("reject_steal", %{"challenge_id" => challenge_id}, %{assigns: %{player_token: player_token}} = socket) do
    Game.challenge_vote(socket.assigns.game_id, player_token, String.to_integer(challenge_id), false)
    {:noreply, socket}
  end

  def handle_event("leave_waiting_game", _params, %{assigns: %{player_token: player_token}} = socket) do
    Game.leave_waiting_game(socket.assigns.game_id, player_token)
    {:noreply, redirect(socket, to: ~p"/clear")}
  end

  def handle_event("quit_game", _params, %{assigns: %{player_token: player_token}} = socket) do
    Game.quit_game(socket.assigns.game_id, player_token)
    {:noreply, redirect(socket, to: ~p"/clear")}
  end

  def handle_info({:new_state, state}, socket) do
    socket =
      assign(socket,
        game_state: state,
        game_progress_bar: state.status == :playing
      )
      |> set_page_title()
    {:noreply, socket}
  end

  # TODO: to avoid name-related mistakes, lookup index from Game? names should be uniq anyway.
  def determine_my_turn_idx(player_name, game_state) do
    Enum.find_index(game_state.players, fn %{name: name} -> name == player_name end)
  end

  defp reset_word_form(socket) do
    socket = assign(socket, word_form: to_form(%{"word" => ""}))
    socket
  end

  defp has_voted?(challenge, player_name) do
    Map.has_key?(challenge.votes, player_name)
  end

  defp rank_players(players_with_scores) do
    {_, ranked_players} =
      players_with_scores
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.reduce({0, []}, fn %{score: score} = player, {prev_rank, ranked_players} ->
        if ranked_players != [] do
          {_, prev_ranked_player} = List.last(ranked_players)
          # if current player tied with previous player, use same rank
          if prev_ranked_player.score == score do
            {prev_rank, ranked_players ++ [{prev_rank, player}]}
          else
            # if current player not tied with previous player, use next rank
            {prev_rank+1, ranked_players ++ [{prev_rank+1, player}]}
          end
        else
          # if no previous players, use next rank
          {prev_rank+1, ranked_players ++ [{prev_rank+1, player}]}
        end
      end)

    ranked_players
  end

  def set_page_title(socket) do
    title =
      if socket.assigns.game_state.status == :playing && socket.assigns.my_turn_idx == socket.assigns.game_state.turn do
        "YOUR TURN - Pirate Scrabble"
      else
        "Pirate Scrabble"
      end

    assign(socket, page_title: title)
  end
end
