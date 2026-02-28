defmodule Piratex.GameTest do
  use ExUnit.Case

  alias Piratex.Game
  alias Piratex.Team
  alias Piratex.Config

  describe "Join Game" do
    test "game not found" do
      assert {:error, :not_found} = Game.join_game("game_id", "player1", "token1")
    end

    test "new game, 2 players join" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      {:ok, %{status: :waiting}} = Game.get_state(game_id)

      :ok = Game.join_game(game_id, "player1", "token1")

      t1_name = Team.default_name("player1")

      # ensure team is auto created for player and player auto-joins
      {:ok,
       %{
         players: [%{name: "player1"}],
         teams: [%{name: ^t1_name, id: team_id}],
         players_teams: %{"player1" => team_id}
       }} = Game.get_state(game_id)

      :ok = Game.join_game(game_id, "player2", "token2")

      t2_name = Team.default_name("player2")

      {:ok,
       %{
         players: [%{name: "player1"}, %{name: "player2"}],
         teams: [%{name: ^t1_name, id: team_id}, %{name: ^t2_name, id: team2_id}],
         players_teams: %{"player1" => team_id, "player2" => team2_id}
       }} = Game.get_state(game_id)

      :ok = Game.start_game(game_id, "token1")

      {:ok, %{status: :playing, players: [_, _]}} = Game.get_state(game_id)
    end

    test "new game max_players join and next player rejected" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()
      max_players = Piratex.Config.max_players()

      for i <- 1..max_players do
        :ok = Game.join_game(game_id, "player#{i}", "token#{i}")
      end

      assert {:error, :game_full} =
               Game.join_game(game_id, "player#{max_players + 1}", "token#{max_players + 1}")

      {:ok, %{players: players, teams: teams}} = Game.get_state(game_id)

      # check that no more players are accepted
      assert length(players) == max_players
      # check that extra teams are not created
      assert length(teams) == Config.max_teams()
    end

    test "new game player name too short" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      assert {:error, :player_name_too_short} =
               Game.join_game(
                 game_id,
                 String.duplicate("a", Piratex.Config.min_player_name() - 1),
                 "token1"
               )
    end

    test "new game player name too long" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      assert {:error, :player_name_too_long} =
               Game.join_game(
                 game_id,
                 String.duplicate("a", Piratex.Config.max_player_name() + 1),
                 "token1"
               )
    end

    test "unique player name and token" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      assert {:error, :duplicate_player} = Game.join_game(game_id, "player1", "token1")
      assert {:error, :duplicate_player} = Game.join_game(game_id, "player1", "token2")
      assert {:error, :duplicate_player} = Game.join_game(game_id, "player2", "token1")
    end

    test "player name may overlap with an extant team name and joins that team" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.create_team(game_id, "token1", "pirates")

      {:ok, %{teams: [%{name: "pirates", id: pirates_team_id}]}} = Game.get_state(game_id)

      :ok = Game.join_game(game_id, "pirates", "token2")

      {:ok,
       %{
         teams: teams,
         players_teams: %{"player1" => ^pirates_team_id, "pirates" => ^pirates_team_id}
       }} = Game.get_state(game_id)

      assert Enum.count(teams, fn team -> team.name == "pirates" end) == 1
    end

    test "player tries to join late" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")
      :ok = Game.join_game(game_id, "player3", "token3")

      :ok = Game.start_game(game_id, "token1")

      {:ok, %{status: :playing} = _state} = Game.get_state(game_id)

      {:error, :game_already_started} = Game.join_game(game_id, "player4", "token4")
    end
  end

  describe "Create Team" do
    test "non-player tries to create a team" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      assert {:error, :player_not_found} = Game.create_team(game_id, "bad_token", "fake_team")
    end

    test "single player renames team" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      :ok = Game.create_team(game_id, "token1", "MyTeam")

      {:ok, %{teams: [%{name: "MyTeam"}]}} = Game.get_state(game_id)
    end

    test "can create team name matching an existing player name" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.create_team(game_id, "token1", "Blue")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.create_team(game_id, "token2", "player1")

      {:ok, %{teams: teams, players_teams: %{"player2" => player1_team_id}}} =
        Game.get_state(game_id)

      assert Enum.any?(teams, fn team -> team.id == player1_team_id and team.name == "player1" end)
    end

    test "2 players, each rename their teams" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      t1_name = Team.default_name("player1")
      t2_name = Team.default_name("player2")

      {:ok,
       %{
         teams: [%{name: ^t1_name, id: team1_id}, %{name: ^t2_name, id: team2_id}],
         players_teams: %{
           "player1" => team1_id,
           "player2" => team2_id
         }
       }} = Game.get_state(game_id)

      :ok = Game.create_team(game_id, "token2", "Mario")

      {:ok,
       %{
         teams: [%{name: ^t1_name, id: team1_id}, %{name: "Mario", id: team2_id}],
         players_teams: %{
           "player1" => team1_id,
           "player2" => team2_id
         }
       }} = Game.get_state(game_id)

      :ok = Game.create_team(game_id, "token1", "Luigi")

      {:ok,
       %{
         teams: [%{name: "Mario", id: team2_id}, %{name: "Luigi", id: team1_id}],
         players_teams: %{
           "player1" => team1_id,
           "player2" => team2_id
         }
       }} = Game.get_state(game_id)
    end

    test "more players join than max_teams, auto-assign team" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      max_teams = Config.max_teams()

      for i <- 1..max_teams do
        :ok = Game.join_game(game_id, "player_#{i}", "token_#{i}")
      end

      {:ok,
       %{
         teams: teams
       }} = Game.get_state(game_id)

      assert length(teams) == max_teams

      :ok = Game.join_game(game_id, "new_player", "new_token")

      # assert that new player is on the first team and no new team
      # was created
      {:ok,
       %{
         teams: [%{id: team1_id} | _] = teams,
         players_teams: %{"new_player" => team1_id}
       }} = Game.get_state(game_id)

      assert length(teams) == max_teams
    end
  end

  describe "Rejoin Game" do
    test "player not found" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      assert {:error, :not_found} = Game.rejoin_game(game_id, "player1", "token1")
    end

    test "success" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      assert :ok = Game.rejoin_game(game_id, "player1", "token1")
      assert :ok = Game.rejoin_game(game_id, "player1", "token1")

      assert :ok = Game.rejoin_game(game_id, "player2", "token2")
      assert :ok = Game.rejoin_game(game_id, "player2", "token2")

      assert {:error, :not_found} = Game.rejoin_game(game_id, "player3", "token3")
    end
  end

  describe "Leave Waiting Game" do
    test "game is not waiting" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      :ok = Game.start_game(game_id, "token1")

      assert {:error, :game_already_started} = Game.leave_waiting_game(game_id, "token1")
    end

    test "success" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      {:ok, %{players: [_, _], status: :waiting}} = Game.get_state(game_id)

      assert :ok = Game.leave_waiting_game(game_id, "token1")

      {:ok, %{players: [_player2], status: :waiting}} = Game.get_state(game_id)

      # game should terminate when last player leaves during waiting state
      assert :ok = Game.leave_waiting_game(game_id, "token2")
      # TODO: find a better way to ensure stop is processed before the Registry lookup below
      :timer.sleep(100)

      assert [] = Registry.lookup(Piratex.Game.Registry, game_id)
    end

    test "quit before game starts is handled as leave waiting game" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.quit_game(game_id, "token1")

      {:ok, %{status: :waiting, players: [%{name: "player2"}]}} = Game.get_state(game_id)
    end
  end

  describe "Start Game" do
    test "game not found" do
      assert {:error, :not_found} = Game.start_game("game_id", "token1")
    end

    test "start a 1 player game" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      :ok = Game.start_game(game_id, "token1")

      {:ok, %{status: :playing} = _state} = Game.get_state(game_id)
    end

    test "start a 2 player game" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      {:ok, %{status: :playing} = _state} = Game.get_state(game_id)

      {:error, :game_already_started} = Game.start_game(game_id, "token1")
      {:error, :game_already_started} = Game.start_game(game_id, "token2")

      {:ok, %{status: :playing} = _state} = Game.get_state(game_id)
    end

    test "start a 2 player game - non-first player starts" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token2")

      {:ok, %{status: :playing} = _state} = Game.get_state(game_id)

      {:error, :game_already_started} = Game.start_game(game_id, "token1")
      {:error, :game_already_started} = Game.start_game(game_id, "token2")

      {:ok, %{status: :playing} = _state} = Game.get_state(game_id)
    end
  end

  describe "Flip Letter" do
    test "game not found" do
      assert {:error, :not_found} = Game.flip_letter("game_id", "token1")
    end

    test "one player" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      assert {:error, :game_not_playing} = Game.flip_letter(game_id, "token1")

      :ok = Game.set_letter_pool_type(game_id, :bananagrams_half)

      :ok = Game.start_game(game_id, "token1")

      assert {:ok, %{status: :playing}} = Game.get_state(game_id)

      assert :ok = Game.flip_letter(game_id, "token1")
      assert {:ok, %{center: [_letter]}} = Game.get_state(game_id)

      assert :ok = Game.flip_letter(game_id, "token1")
      assert {:ok, %{center: [_, _]}} = Game.get_state(game_id)
    end

    test "two players" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.set_letter_pool_type(game_id, :bananagrams_half)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      assert {:error, :game_not_playing} = Game.flip_letter(game_id, "token1")

      :ok = Game.start_game(game_id, "token1")

      assert {:ok, %{status: :playing}} = Game.get_state(game_id)

      # NOT p2's turn
      assert {:error, :not_your_turn} = Game.flip_letter(game_id, "token2")
      assert {:ok, %{center: []}} = Game.get_state(game_id)

      # p1's turn
      assert :ok = Game.flip_letter(game_id, "token1")
      assert {:ok, %{center: [_letter]}} = Game.get_state(game_id)

      # NOT p1's turn
      assert {:error, :not_your_turn} = Game.flip_letter(game_id, "token1")
      assert {:ok, %{center: [_]}} = Game.get_state(game_id)

      # p2's turn
      assert :ok = Game.flip_letter(game_id, "token2")
      assert {:ok, %{center: [_, _]}} = Game.get_state(game_id)

      # NOT p2's turn
      assert {:error, :not_your_turn} = Game.flip_letter(game_id, "token2")
      assert {:ok, %{center: [_, _]}} = Game.get_state(game_id)
    end

    test "no flip with open challenge" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          challenges: [
            %Piratex.WordSteal{
              victim_team_idx: 0,
              victim_word: "test",
              thief_team_idx: 1,
              thief_player_idx: 1,
              thief_word: "tests"
            }
          ]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      assert {:error, :challenge_open} = Game.flip_letter(game_id, "token1")
    end
  end

  describe "Claim Word" do
    test "game not found" do
      assert {:error, :not_found} = Game.claim_word("game_id", "token1", "test")
    end

    test "successful claim from center" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["s", "e", "t"],
          center_sorted: ["e", "s", "t"]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      assert :ok = Game.claim_word(game_id, "token1", "set")
      assert {:ok, %{center: []}} = Game.get_state(game_id)
    end

    test "successful steal" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["t", "s", "e", "t"],
          center_sorted: ["e", "s", "t", "t"]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      assert :ok = Game.claim_word(game_id, "token1", "set")

      t1_name = Team.default_name("player1")
      t2_name = Team.default_name("player2")

      assert {:ok,
              %{
                center: ["t"],
                players: [
                  %{name: "player1"},
                  %{name: "player2"}
                ],
                teams: [
                  %{name: ^t1_name, words: ["set"]},
                  %{name: ^t2_name, words: []}
                ]
              }} = Game.get_state(game_id)

      assert :ok = Game.claim_word(game_id, "token2", "test")

      t1_name = Team.default_name("player1")
      t2_name = Team.default_name("player2")

      assert {:ok,
              %{
                center: [],
                players: [
                  %{name: "player1"},
                  %{name: "player2"}
                ],
                teams: [
                  %{name: ^t1_name, words: []},
                  %{name: ^t2_name, words: ["test"]}
                ]
              }} = Game.get_state(game_id)
    end

    test "cannot claim recidivist word" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["t", "s", "e", "t", "s"],
          center_sorted: ["e", "s", "s", "t", "t"],
          past_challenges: [
            %Piratex.ChallengeService.Challenge{
              word_steal: %Piratex.WordSteal{
                victim_team_idx: 0,
                victim_word: "test",
                thief_team_idx: 1,
                thief_player_idx: 1,
                thief_word: "tests"
              },
              votes: %{},
              # steal rejected
              result: false,
              id: 0
            }
          ]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      assert :ok = Game.claim_word(game_id, "token2", "test")

      t1_name = Team.default_name("player1")
      t2_name = Team.default_name("player2")

      assert {:ok,
              %{
                center: ["s"],
                players: [
                  %{name: "player1"},
                  %{name: "player2"}
                ],
                teams: [
                  %{name: ^t1_name, words: []},
                  %{name: ^t2_name, words: ["test"]}
                ]
              }} = Game.get_state(game_id)

      assert {:error, :invalid_word} = Game.claim_word(game_id, "token2", "tests")

      assert {:ok,
              %{
                center: ["s"],
                players: [
                  %{name: "player1"},
                  %{name: "player2"}
                ],
                teams: [
                  %{name: ^t1_name, words: []},
                  %{name: ^t2_name, words: ["test"]}
                ]
              }} = Game.get_state(game_id)
    end

    test "multiple players on same team" do
      Piratex.TestHelpers.default_new_game(0, %{
        status: :waiting,
        center: ["t", "s", "e", "t", "s"],
        center_sorted: ["e", "s", "s", "t", "t"],
        past_challenges: []
      })

      # TODO
    end
  end

  describe "Challenge Word" do
    test "game not found" do
      assert {:error, :not_found} = Game.challenge_word("game_id", "token1", "test")
    end

    test "invalid challenge" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["t", "s", "e", "t", "s"],
          center_sorted: ["e", "s", "s", "t", "t"]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      assert {:error, :game_not_playing} = Game.challenge_word(game_id, "token1", "test")

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      assert {:error, :word_not_in_play} = Game.challenge_word(game_id, "token1", "test")

      assert :ok = Game.claim_word(game_id, "token1", "test")
      assert :ok = Game.claim_word(game_id, "token2", "tests")
      assert {:error, :word_not_in_play} = Game.challenge_word(game_id, "token1", "test")
    end

    test "vote on non-existent challenge" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      assert {:error, :challenge_not_found} = Game.challenge_vote(game_id, "token1", 0, false)
    end

    test "successful challenge" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["t", "s", "e", "t", "s"],
          center_sorted: ["e", "s", "s", "t", "t"]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      :ok = Game.claim_word(game_id, "token1", "test")

      t1_name = Team.default_name("player1")
      t2_name = Team.default_name("player2")

      assert {:ok,
              %{
                center: ["s"],
                players: [
                  %{name: "player1"},
                  %{name: "player2"}
                ],
                teams: [
                  %{name: ^t1_name, words: ["test"]},
                  %{name: ^t2_name}
                ]
              }} = Game.get_state(game_id)

      :ok = Game.claim_word(game_id, "token2", "tests")

      assert :ok = Game.challenge_word(game_id, "token1", "tests")

      assert {:ok,
              %{
                challenges: [
                  %Piratex.ChallengeService.Challenge{
                    word_steal: %Piratex.WordSteal{
                      victim_team_idx: 0,
                      victim_word: "test",
                      thief_team_idx: 1,
                      thief_player_idx: 1,
                      thief_word: "tests"
                    },
                    votes: %{"player1" => false},
                    result: nil,
                    id: challenge_id
                  }
                ]
              }} = Game.get_state(game_id)

      # do not allow player1 to vote again
      assert {:error, :already_voted} =
               Game.challenge_vote(game_id, "token1", challenge_id, false)

      assert {:ok,
              %{
                challenges: [
                  %Piratex.ChallengeService.Challenge{
                    votes: %{"player1" => false},
                    result: nil,
                    id: ^challenge_id
                  }
                ]
              }} = Game.get_state(game_id)

      # player2 admits the word is invalid
      assert :ok = Game.challenge_vote(game_id, "token2", challenge_id, false)

      assert {:ok,
              %{
                past_challenges: [
                  %Piratex.ChallengeService.Challenge{
                    votes: %{"player1" => false, "player2" => false},
                    result: false,
                    id: ^challenge_id
                  }
                ]
              }} = Game.get_state(game_id)
    end

    test "no double jeopardy" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["a", "e", "t", "s"],
          center_sorted: ["a", "e", "s", "t"]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      :ok = Game.claim_word(game_id, "token1", "eat")

      t1_name = Team.default_name("player1")
      t2_name = Team.default_name("player2")

      assert {:ok,
              %{
                center: ["s"],
                players: [
                  %{name: "player1"},
                  %{name: "player2"}
                ],
                teams: [
                  %{name: ^t1_name, words: ["eat"]},
                  %{name: ^t2_name, words: []}
                ]
              }} = Game.get_state(game_id)

      :ok = Game.claim_word(game_id, "token2", "east")

      assert :ok = Game.challenge_word(game_id, "token1", "east")

      assert {:ok,
              %{
                challenges: [
                  %Piratex.ChallengeService.Challenge{
                    word_steal: %Piratex.WordSteal{
                      victim_team_idx: 0,
                      victim_word: "eat",
                      thief_team_idx: 1,
                      thief_player_idx: 1,
                      thief_word: "east"
                    },
                    votes: %{"player1" => false},
                    result: nil,
                    id: challenge_id
                  }
                ]
              }} = Game.get_state(game_id)

      # player2 votes valid. tie goes to the new word
      assert :ok = Game.challenge_vote(game_id, "token2", challenge_id, true)

      assert {:ok,
              %{
                challenges: [],
                past_challenges: [
                  %Piratex.ChallengeService.Challenge{
                    votes: %{"player1" => false, "player2" => true},
                    result: true,
                    id: ^challenge_id
                  }
                ]
              }} = Game.get_state(game_id)

      # player1 votes invalid. word is now invalid
      assert {:error, :already_challenged} = Game.challenge_word(game_id, "token1", "east")

      assert {:ok,
              %{
                challenges: [],
                past_challenges: [
                  %Piratex.ChallengeService.Challenge{
                    result: true,
                    id: ^challenge_id
                  }
                ]
              }} = Game.get_state(game_id)
    end
  end

  describe "Game Over" do
    test "2 players" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["t", "s", "e", "t", "s", "a", "t"],
          center_sorted: ["a", "e", "s", "s", "t", "t", "t"],
          letter_pool: ["b"]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      assert {:ok, %{letter_pool: ["b"]}} = Game.get_state(game_id)

      refute Piratex.Helpers.no_more_letters?(state)

      :ok = Game.claim_word(game_id, "token1", "test")

      :ok = Game.claim_word(game_id, "token2", "sat")

      {:ok, _state} = Game.get_state(game_id)

      assert {:ok, %{status: :playing}} = Game.get_state(game_id)

      assert :ok = Game.flip_letter(game_id, "token1")
      assert {:ok, %{status: :playing, letter_pool: []} = state} = Game.get_state(game_id)

      assert Piratex.Helpers.no_more_letters?(state)

      :ok = Game.end_game_vote(game_id, "token1")

      assert {:ok, %{status: :playing} = _state} = Game.get_state(game_id)

      :ok = Game.end_game_vote(game_id, "token2")

      :ok = Piratex.TestHelpers.wait_for_state_match(game_id, %{status: :finished})

      t1_name = Team.default_name("player1")
      t2_name = Team.default_name("player2")

      assert {:ok,
              %{
                status: :finished,
                teams: [%{name: ^t1_name, score: 3}, %{name: ^t2_name, score: 2}]
              }} =
               Game.get_state(game_id)
    end

    test "2 players, 1 quit" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["t", "s", "e", "t", "s", "a", "t"],
          center_sorted: ["a", "e", "s", "s", "t", "t", "t"],
          letter_pool: ["b"]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      :ok = Game.claim_word(game_id, "token1", "test")

      :ok = Game.quit_game(game_id, "token2")

      t1_name = Team.default_name("player1")
      t2_name = Team.default_name("player2")

      assert {:ok,
              %{
                status: :playing,
                teams: [%{name: ^t1_name, score: 0}, %{name: ^t2_name, score: 0}]
              }} = Game.get_state(game_id)

      assert :ok = Game.flip_letter(game_id, "token1")
      assert {:ok, %{status: :playing, letter_pool: []} = state} = Game.get_state(game_id)

      assert Piratex.Helpers.no_more_letters?(state)

      :ok = Game.end_game_vote(game_id, "token1")

      :ok = Piratex.TestHelpers.wait_for_state_match(game_id, %{status: :finished})

      t1_name = Team.default_name("player1")
      t2_name = Team.default_name("player2")

      assert {:ok,
              %{
                status: :finished,
                teams: [%{name: ^t1_name, score: 3}, %{name: ^t2_name, score: 0}]
              }} = Game.get_state(game_id)
    end

    test "2 players, 1 quit after 1st vote" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["t", "s", "e", "t", "s", "a", "t"],
          center_sorted: ["a", "e", "s", "s", "t", "t", "t"],
          letter_pool: ["b"]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      :ok = Game.claim_word(game_id, "token1", "test")

      t1_name = Team.default_name("player1")
      t2_name = Team.default_name("player2")

      assert {:ok,
              %{
                status: :playing,
                teams: [%{name: ^t1_name, score: 0}, %{name: ^t2_name, score: 0}]
              }} = Game.get_state(game_id)

      assert :ok = Game.flip_letter(game_id, "token1")
      assert {:ok, %{status: :playing, letter_pool: []} = state} = Game.get_state(game_id)

      assert Piratex.Helpers.no_more_letters?(state)

      :ok = Game.end_game_vote(game_id, "token1")

      :ok = Game.quit_game(game_id, "token2")

      :ok = Piratex.TestHelpers.wait_for_state_match(game_id, %{status: :finished})

      t1_name = Team.default_name("player1")
      t2_name = Team.default_name("player2")

      assert {:ok,
              %{
                status: :finished,
                teams: [%{name: ^t1_name, score: 3}, %{name: ^t2_name, score: 0}]
              }} = Game.get_state(game_id)
    end

    test "3 players, 1 votes then quits, then 1 votes. Do not end because 3rd person has not voted" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["m", "e", "t", "s", "e", "t", "s", "a", "t"],
          center_sorted: ["a", "e", "e", "m", "s", "s", "t", "t", "t"],
          letter_pool: ["b"]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")
      :ok = Game.join_game(game_id, "player3", "token3")

      :ok = Game.start_game(game_id, "token1")

      :ok = Game.claim_word(game_id, "token1", "met")
      :ok = Game.claim_word(game_id, "token2", "set")
      :ok = Game.claim_word(game_id, "token3", "sat")

      :ok = Game.flip_letter(game_id, "token1")
      assert {:ok, %{status: :playing, letter_pool: []} = _state} = Game.get_state(game_id)

      :ok = Game.end_game_vote(game_id, "token1")
      :ok = Game.quit_game(game_id, "token1")

      # do not end game because player2 has not voted
      :ok = Game.end_game_vote(game_id, "token2")

      # how to check that the game doesn't end? For now, just check 50 times and hope eng_game doesn't take longer than that.
      {:incorrect_state, _} =
        Piratex.TestHelpers.wait_for_state_match(game_id, %{status: :finished})

      :ok = Game.end_game_vote(game_id, "token3")

      :ok = Piratex.TestHelpers.wait_for_state_match(game_id, %{status: :finished})

      t1_name = Team.default_name("player1")
      t2_name = Team.default_name("player2")
      t3_name = Team.default_name("player3")

      assert {:ok,
              %{
                status: :finished,
                teams: [
                  %{name: ^t1_name, score: 2},
                  %{name: ^t2_name, score: 2},
                  %{name: ^t3_name, score: 2}
                ]
              }} = Game.get_state(game_id)
    end

    test "3 players" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["m", "e", "t", "s", "e", "t", "s", "a", "t"],
          center_sorted: ["a", "e", "e", "m", "s", "s", "t", "t", "t"],
          letter_pool: ["b"]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")
      :ok = Game.join_game(game_id, "player3", "token3")

      :ok = Game.start_game(game_id, "token1")

      :ok = Game.claim_word(game_id, "token1", "met")
      :ok = Game.claim_word(game_id, "token2", "set")
      :ok = Game.claim_word(game_id, "token3", "sat")

      :ok = Game.flip_letter(game_id, "token1")
      assert {:ok, %{status: :playing, letter_pool: []} = _state} = Game.get_state(game_id)

      :ok = Game.end_game_vote(game_id, "token1")
      :ok = Game.end_game_vote(game_id, "token2")
      :ok = Game.end_game_vote(game_id, "token3")

      :ok = Piratex.TestHelpers.wait_for_state_match(game_id, %{status: :finished})

      t1_name = Team.default_name("player1")
      t2_name = Team.default_name("player2")
      t3_name = Team.default_name("player3")

      assert {:ok,
              %{
                status: :finished,
                teams: [
                  %{name: ^t1_name, score: 2},
                  %{name: ^t2_name, score: 2},
                  %{name: ^t3_name, score: 2}
                ]
              }} = Game.get_state(game_id)
    end

    test "3 players, 2 quit last" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["m", "e", "t", "s", "e", "t", "s", "a", "t"],
          center_sorted: ["a", "e", "e", "m", "s", "s", "t", "t", "t"],
          letter_pool: ["b"]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")
      :ok = Game.join_game(game_id, "player3", "token3")

      :ok = Game.start_game(game_id, "token1")

      :ok = Game.claim_word(game_id, "token1", "met")
      :ok = Game.claim_word(game_id, "token2", "set")
      :ok = Game.claim_word(game_id, "token3", "sat")

      :ok = Game.flip_letter(game_id, "token1")
      assert {:ok, %{status: :playing, letter_pool: []} = _state} = Game.get_state(game_id)

      :ok = Game.end_game_vote(game_id, "token1")
      :ok = Game.quit_game(game_id, "token2")
      :ok = Game.quit_game(game_id, "token3")

      :ok = Piratex.TestHelpers.wait_for_state_match(game_id, %{status: :finished})

      t1_name = Team.default_name("player1")
      t2_name = Team.default_name("player2")
      t3_name = Team.default_name("player3")

      assert {:ok,
              %{
                status: :finished,
                teams: [
                  %{name: ^t1_name, score: 2},
                  %{name: ^t2_name, score: 2},
                  %{name: ^t3_name, score: 2}
                ]
              }} = Game.get_state(game_id)
    end

    test "3 players, 2 quit first" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["m", "e", "t", "s", "e", "t", "s", "a", "t"],
          center_sorted: ["a", "e", "e", "m", "s", "s", "t", "t", "t"],
          letter_pool: ["b"]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")
      :ok = Game.join_game(game_id, "player3", "token3")

      :ok = Game.start_game(game_id, "token1")

      :ok = Game.claim_word(game_id, "token1", "met")
      :ok = Game.claim_word(game_id, "token2", "set")
      :ok = Game.claim_word(game_id, "token3", "sat")

      :ok = Game.flip_letter(game_id, "token1")
      assert {:ok, %{status: :playing, letter_pool: []} = _state} = Game.get_state(game_id)

      :ok = Game.quit_game(game_id, "token2")
      :ok = Game.quit_game(game_id, "token3")
      :ok = Game.end_game_vote(game_id, "token1")

      :ok = Piratex.TestHelpers.wait_for_state_match(game_id, %{status: :finished})

      t1_name = Team.default_name("player1")
      t2_name = Team.default_name("player2")
      t3_name = Team.default_name("player3")

      assert {:ok,
              %{
                status: :finished,
                teams: [
                  %{name: ^t1_name, score: 2},
                  %{name: ^t2_name, score: 2},
                  %{name: ^t3_name, score: 2}
                ]
              }} = Game.get_state(game_id)
    end

    test "4 players" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["m", "e", "t", "s", "e", "t", "s", "a", "t"],
          center_sorted: ["a", "e", "e", "m", "s", "s", "t", "t", "t"],
          letter_pool: ["b"]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")
      :ok = Game.join_game(game_id, "player3", "token3")
      :ok = Game.join_game(game_id, "player4", "token4")
      :ok = Game.start_game(game_id, "token1")

      :ok = Game.claim_word(game_id, "token1", "met")
      :ok = Game.claim_word(game_id, "token2", "set")
      :ok = Game.claim_word(game_id, "token3", "sat")

      :ok = Game.flip_letter(game_id, "token1")
      assert {:ok, %{status: :playing, letter_pool: []} = _state} = Game.get_state(game_id)

      :ok = Game.end_game_vote(game_id, "token1")
      # duplicate votes are not counted
      :ok = Game.end_game_vote(game_id, "token1")
      :ok = Game.end_game_vote(game_id, "token1")
      :ok = Game.end_game_vote(game_id, "token2")

      {:incorrect_state, %{end_game_votes: end_game_votes}} =
        Piratex.TestHelpers.wait_for_state_match(game_id, %{status: :finished})

      # assert that ONLY 2 players have voted
      assert %{"player1" => true, "player2" => true} == end_game_votes

      :ok = Game.end_game_vote(game_id, "token3")
      :ok = Game.end_game_vote(game_id, "token4")

      :ok = Piratex.TestHelpers.wait_for_state_match(game_id, %{status: :finished})

      t1_name = Team.default_name("player1")
      t2_name = Team.default_name("player2")
      t3_name = Team.default_name("player3")
      t4_name = Team.default_name("player4")

      assert {:ok,
              %{
                status: :finished,
                teams: [
                  %{name: ^t1_name, score: 2},
                  %{name: ^t2_name, score: 2},
                  %{name: ^t3_name, score: 2},
                  %{name: ^t4_name, score: 0}
                ]
              }} = Game.get_state(game_id)
    end

    test "5 players" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["m", "e", "t", "s", "e", "t", "s", "a", "t"],
          center_sorted: ["a", "e", "e", "m", "s", "s", "t", "t", "t"],
          letter_pool: ["b"]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")
      :ok = Game.join_game(game_id, "player3", "token3")
      :ok = Game.join_game(game_id, "player4", "token4")
      :ok = Game.join_game(game_id, "player5", "token5")
      :ok = Game.start_game(game_id, "token1")

      :ok = Game.claim_word(game_id, "token1", "met")
      :ok = Game.claim_word(game_id, "token2", "set")
      :ok = Game.claim_word(game_id, "token3", "sat")

      :ok = Game.flip_letter(game_id, "token1")
      assert {:ok, %{status: :playing, letter_pool: []} = _state} = Game.get_state(game_id)

      :ok = Game.end_game_vote(game_id, "token1")
      :ok = Game.end_game_vote(game_id, "token2")
      :ok = Game.end_game_vote(game_id, "token3")
      :ok = Game.end_game_vote(game_id, "token4")
      :ok = Game.end_game_vote(game_id, "token5")

      :ok = Piratex.TestHelpers.wait_for_state_match(game_id, %{status: :finished})

      t1_name = Team.default_name("player1")
      t2_name = Team.default_name("player2")
      t3_name = Team.default_name("player3")
      t4_name = Team.default_name("player4")
      t5_name = Team.default_name("player5")

      assert {:ok,
              %{
                status: :finished,
                teams: [
                  %{name: ^t1_name, score: 2},
                  %{name: ^t2_name, score: 2},
                  %{name: ^t3_name, score: 2},
                  %{name: ^t4_name, score: 0},
                  %{name: ^t5_name, score: 0}
                ]
              }} = Game.get_state(game_id)
    end
  end

  describe "Game.new_game/1" do
    test "creates a new Game struct with the given id" do
      game = Game.new_game("TESTID")

      assert %Game{} = game
      assert game.id == "TESTID"
      assert game.status == :waiting
      assert game.start_time == nil
      assert game.end_time == nil
      assert game.players_teams == %{}
      assert game.teams == []
      assert game.players == []
      assert game.total_turn == 0
      assert game.turn == 0
      assert game.letter_pool == []
      assert game.initial_letter_count == 0
      assert game.center == []
      assert game.center_sorted == []
      assert game.history == []
      assert game.challenges == []
      assert game.past_challenges == []
      assert game.end_game_votes == %{}
      assert game.game_stats == nil
      assert %DateTime{} = game.last_action_at
    end
  end

  describe "Game.new_game_id/0" do
    test "returns a string" do
      id = Game.new_game_id()
      assert is_binary(id)
    end

    test "returns an uppercase string" do
      id = Game.new_game_id()
      assert id == String.upcase(id)
    end

    test "two calls produce different IDs" do
      id1 = Game.new_game_id()
      id2 = Game.new_game_id()
      assert id1 != id2
    end
  end

  describe "Set Letter Pool Type" do
    test "set to :bananagrams during waiting" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      assert :ok = Game.set_letter_pool_type(game_id, :bananagrams)

      {:ok, %{letter_pool: letter_pool, initial_letter_count: count}} = Game.get_state(game_id)
      assert length(letter_pool) > 0
      assert count > 0
    end

    test "set to :bananagrams_half during waiting" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      assert :ok = Game.set_letter_pool_type(game_id, :bananagrams_half)

      {:ok, %{letter_pool: letter_pool, initial_letter_count: count}} = Game.get_state(game_id)
      assert length(letter_pool) > 0
      assert count > 0
    end

    test "cannot set after game started" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.start_game(game_id, "token1")

      assert {:error, :game_already_started} =
               Game.set_letter_pool_type(game_id, :bananagrams_half)
    end

    test "game not found" do
      assert {:error, :not_found} = Game.set_letter_pool_type("nonexistent", :bananagrams)
    end
  end

  describe "Join Team" do
    test "player joins a different team during waiting" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      t1_name = Team.default_name("player1")
      t2_name = Team.default_name("player2")

      {:ok,
       %{
         teams: [%{name: ^t1_name, id: team1_id}, %{name: ^t2_name, id: _team2_id}],
         players_teams: players_teams
       }} = Game.get_state(game_id)

      assert players_teams["player1"] == team1_id
      assert players_teams["player2"] != team1_id

      # player2 joins player1's team
      assert :ok = Game.join_team(game_id, "token2", team1_id)

      {:ok,
       %{
         teams: [%{name: ^t1_name, id: ^team1_id}],
         players_teams: new_players_teams
       }} = Game.get_state(game_id)

      assert new_players_teams["player1"] == team1_id
      assert new_players_teams["player2"] == team1_id
    end

    test "game not found" do
      assert {:error, :not_found} = Game.join_team("nonexistent", "token1", 123)
    end
  end

  describe "Get State" do
    test "get state of existing game" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      {:ok, state} = Game.get_state(game_id)
      assert is_map(state)
      assert state.status == :waiting
      assert state.id == game_id
    end

    test "game not found" do
      assert {:error, :not_found} = Game.get_state("nonexistent")
    end
  end

  describe "Get Players Teams" do
    test "returns sanitized players_teams with player names not tokens" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      result = Game.get_players_teams(game_id)

      assert is_map(result)
      assert Map.has_key?(result, "player1")
      assert Map.has_key?(result, "player2")
      refute Map.has_key?(result, "token1")
      refute Map.has_key?(result, "token2")
    end

    test "game not found" do
      assert {:error, :not_found} = Game.get_players_teams("nonexistent")
    end
  end

  describe "Quit Game" do
    test "player quits and it was their turn, turn advances" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")
      :ok = Game.join_game(game_id, "player3", "token3")

      :ok = Game.start_game(game_id, "token1")

      # turn 0 is player1's turn
      {:ok, %{turn: 0}} = Game.get_state(game_id)

      # player1 quits while it's their turn
      :ok = Game.quit_game(game_id, "token1")

      # turn should advance past the quitter to player2
      {:ok, %{turn: turn, players: players}} = Game.get_state(game_id)
      current_player = Enum.at(players, turn)
      assert current_player.name == "player2"
    end

    test "quit a non-existent game returns error" do
      assert {:error, :not_found} = Game.quit_game("nonexistent", "token1")
    end

    test "all players quit during game, game stops" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      :ok = Game.quit_game(game_id, "token1")
      :ok = Game.quit_game(game_id, "token2")

      # game should stop after all players quit
      :timer.sleep(1500)

      assert [] = Registry.lookup(Piratex.Game.Registry, game_id)
    end
  end

  describe "End Game Vote" do
    test "vote on non-playing game returns error" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      # game is still in :waiting status
      assert {:error, :game_not_playing} = Game.end_game_vote(game_id, "token1")
    end

    test "player not found returns error" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          letter_pool: ["a"]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      :ok = Game.flip_letter(game_id, "token1")

      assert {:error, :not_found} = Game.end_game_vote(game_id, "bad_token")
    end

    test "game not found returns error" do
      assert {:error, :not_found} = Game.end_game_vote("nonexistent", "token1")
    end
  end

  describe "Game.via_tuple/1" do
    test "returns correct registry tuple" do
      game_id = "TESTGAME"
      result = Game.via_tuple(game_id)

      assert {:via, Registry, {Piratex.Game.Registry, ^game_id}} = result
    end
  end

  describe "Game.events_topic/1" do
    test "returns correctly formatted topic string" do
      game_id = "TESTGAME"
      result = Game.events_topic(game_id)

      assert result == "game-events:TESTGAME"
    end

    test "topic format is consistent" do
      game_id1 = "ABC123"
      game_id2 = "XYZ789"

      assert Game.events_topic(game_id1) == "game-events:ABC123"
      assert Game.events_topic(game_id2) == "game-events:XYZ789"
    end
  end

  describe "Game.find_by_id/1" do
    test "finds existing game and returns state" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      assert {:ok, state} = Game.find_by_id(game_id)
      assert state.id == game_id
      assert state.status == :waiting
      assert length(state.players) == 1
    end

    test "returns error for non-existent game" do
      assert {:error, :not_found} = Game.find_by_id("NONEXISTENT")
    end

    test "returns error for stopped game" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.leave_waiting_game(game_id, "token1")

      :timer.sleep(100)

      assert {:error, :not_found} = Game.find_by_id(game_id)
    end
  end

  describe "Game.set_last_action_at/1" do
    test "updates last_action_at to current time" do
      game = Game.new_game("TEST")
      original_time = game.last_action_at

      :timer.sleep(10)

      updated_game = Game.set_last_action_at(game)

      assert %DateTime{} = updated_game.last_action_at
      assert DateTime.compare(updated_game.last_action_at, original_time) == :gt
    end

    test "preserves other fields when updating last_action_at" do
      game = Game.new_game("TEST")
      game = %{game | status: :playing, players: [%{name: "test"}]}

      updated_game = Game.set_last_action_at(game)

      assert updated_game.status == :playing
      assert updated_game.players == [%{name: "test"}]
      assert updated_game.id == "TEST"
    end
  end

  describe "Game.load_letter_pool/2" do
    test "loads bananagrams letter pool" do
      game = Game.new_game("TEST")

      updated_game = Game.load_letter_pool(game, :bananagrams)

      assert length(updated_game.letter_pool) > 0
      assert updated_game.initial_letter_count > 0
      assert length(updated_game.letter_pool) == updated_game.initial_letter_count
    end

    test "loads bananagrams_half letter pool" do
      game = Game.new_game("TEST")

      updated_game = Game.load_letter_pool(game, :bananagrams_half)

      assert length(updated_game.letter_pool) > 0
      assert updated_game.initial_letter_count > 0
      assert length(updated_game.letter_pool) == updated_game.initial_letter_count
    end

    test "bananagrams_half has fewer letters than bananagrams" do
      game = Game.new_game("TEST")

      full_game = Game.load_letter_pool(game, :bananagrams)
      half_game = Game.load_letter_pool(game, :bananagrams_half)

      assert full_game.initial_letter_count > half_game.initial_letter_count
    end
  end

  describe "Game.broadcast_new_state/1" do
    test "broadcasts state to correct topic" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      topic = Game.events_topic(game_id)
      Phoenix.PubSub.subscribe(Piratex.PubSub, topic)

      :ok = Game.join_game(game_id, "player2", "token2")

      assert_receive {:new_state, state}, 500
      assert state.id == game_id
      assert length(state.players) == 2
    end
  end

  describe "Game.broadcast_game_stats/1" do
    test "broadcasts game stats to correct topic" do
      state = Game.new_game("TESTGAME")
      state = %{state | game_stats: %{total_words: 10, total_score: 42}}

      topic = Game.events_topic(state.id)
      Phoenix.PubSub.subscribe(Piratex.PubSub, topic)

      Game.broadcast_game_stats(state)

      assert_receive {:game_stats, stats}, 500
      assert stats.total_words == 10
      assert stats.total_score == 42
    end
  end

  describe "handle_info :timeout" do
    test "game times out when inactive" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      [{pid, _}] = Registry.lookup(Piratex.Game.Registry, game_id)

      assert Process.alive?(pid)

      send(pid, :timeout)

      :timer.sleep(100)

      refute Process.alive?(pid)
      assert [] = Registry.lookup(Piratex.Game.Registry, game_id)
    end
  end

  describe "Team name validation" do
    test "team name too short" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      short_name = String.duplicate("a", Config.min_team_name() - 1)
      assert {:error, :player_name_too_short} = Game.create_team(game_id, "token1", short_name)
    end

    test "team name too long" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      long_name = String.duplicate("a", Config.max_team_name() + 1)
      assert {:error, :player_name_too_long} = Game.create_team(game_id, "token1", long_name)
    end

    test "cannot create more teams than max_teams" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      max_teams = Config.max_teams()

      for i <- 1..max_teams do
        :ok = Game.join_game(game_id, "player#{i}", "token#{i}")
      end

      :ok = Game.join_game(game_id, "extra_player", "extra_token")

      {:ok, %{teams: [%{id: team1_id} | _]}} = Game.get_state(game_id)

      assert {:error, :no_more_teams_allowed} =
               Game.create_team(game_id, "extra_token", "NewTeam")

      {:ok, %{players_teams: players_teams}} = Game.get_state(game_id)

      assert players_teams["extra_player"] == team1_id
    end
  end

  describe "Flip letter with no more letters" do
    test "cannot flip when letter pool is empty" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          letter_pool: []
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")

      :ok = Game.start_game(game_id, "token1")

      assert {:error, :no_more_letters} = Game.flip_letter(game_id, "token1")
    end
  end

  describe "Claim word error cases" do
    test "player not found" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["t", "e", "s", "t"],
          center_sorted: ["e", "s", "t", "t"]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")

      :ok = Game.start_game(game_id, "token1")

      assert {:error, :player_not_found} = Game.claim_word(game_id, "bad_token", "test")
    end

    test "game not playing" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      assert {:error, :game_not_playing} = Game.claim_word(game_id, "token1", "test")
    end

    test "quit player cannot claim word" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["t", "e", "s", "t"],
          center_sorted: ["e", "s", "t", "t"]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      :ok = Game.quit_game(game_id, "token1")

      assert {:error, :player_not_found} = Game.claim_word(game_id, "token1", "test")
    end
  end

  describe "Challenge word error cases" do
    test "game not playing" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      assert {:error, :game_not_playing} = Game.challenge_word(game_id, "token1", "test")
    end

    test "challenge vote on non-playing game" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      assert {:error, :game_not_playing} = Game.challenge_vote(game_id, "token1", 0, true)
    end
  end

  describe "Turn timeout handling" do
    test "turn timeout on past turn is ignored" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.set_letter_pool_type(game_id, :bananagrams_half)

      :ok = Game.start_game(game_id, "token1")

      {:ok, state_before} = Game.get_state(game_id)
      assert state_before.turn == 0

      :ok = Game.flip_letter(game_id, "token1")

      {:ok, state_after_flip} = Game.get_state(game_id)
      assert state_after_flip.turn == 1

      [{pid, _}] = Registry.lookup(Piratex.Game.Registry, game_id)

      send(pid, {:turn_timeout, 0})

      :timer.sleep(50)

      {:ok, state_after_timeout} = Game.get_state(game_id)
      assert state_after_timeout.turn == 1
      assert Process.alive?(pid)
    end
  end

  describe "Start game with custom letter pool" do
    test "game starts with pre-loaded letter pool" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      :ok = Game.set_letter_pool_type(game_id, :bananagrams_half)

      {:ok, %{initial_letter_count: count_before}} = Game.get_state(game_id)
      assert count_before > 0

      :ok = Game.start_game(game_id, "token1")

      {:ok, %{initial_letter_count: count_after, letter_pool: pool}} = Game.get_state(game_id)

      assert count_after == count_before
      assert length(pool) == count_before
    end

    test "game starts with default pool if none set" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      {:ok, %{initial_letter_count: 0}} = Game.get_state(game_id)

      :ok = Game.start_game(game_id, "token1")

      {:ok, %{initial_letter_count: count, letter_pool: pool}} = Game.get_state(game_id)

      assert count > 0
      assert length(pool) == count
    end
  end

  describe "GenServer initialization" do
    test "init with binary id creates new game" do
      game_id = "TESTINIT"

      assert {:ok, state, timeout} = Game.init(game_id)

      assert state.id == game_id
      assert state.status == :waiting
      assert is_integer(timeout)
    end

    test "init with state map preserves state" do
      custom_state = %{
        id: "CUSTOM",
        status: :playing,
        players: [],
        teams: [],
        last_action_at: DateTime.utc_now()
      }

      assert {:ok, state, timeout} = Game.init(custom_state)

      assert state.id == "CUSTOM"
      assert state.status == :playing
      assert is_integer(timeout)
    end
  end

  describe "handle_info :stop" do
    test "game stops on :stop message" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      [{pid, _}] = Registry.lookup(Piratex.Game.Registry, game_id)

      assert Process.alive?(pid)

      send(pid, :stop)

      :timer.sleep(100)

      refute Process.alive?(pid)
      assert [] = Registry.lookup(Piratex.Game.Registry, game_id)
    end
  end

  describe "handle_info :end_game" do
    test "end_game message transitions game to finished" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["t", "e", "s", "t"],
          center_sorted: ["e", "s", "t", "t"],
          letter_pool: []
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      {:ok, %{status: :playing}} = Game.get_state(game_id)

      [{pid, _}] = Registry.lookup(Piratex.Game.Registry, game_id)

      send(pid, :end_game)

      :ok = Piratex.TestHelpers.wait_for_state_match(game_id, %{status: :finished})

      {:ok, %{status: :finished, game_stats: stats}} = Game.get_state(game_id)

      assert is_map(stats)
      assert Process.alive?(pid)
    end
  end

  describe "handle_call :get_players_teams" do
    test "returns sanitized map with player names as keys" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      [{pid, _}] = Registry.lookup(Piratex.Game.Registry, game_id)

      result = GenServer.call(pid, :get_players_teams)

      assert is_map(result)
      assert Map.has_key?(result, "player1")
      assert Map.has_key?(result, "player2")
      refute Map.has_key?(result, "token1")
      refute Map.has_key?(result, "token2")
    end
  end

  describe "handle_call :get_state" do
    test "returns sanitized state without sensitive information" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      [{pid, _}] = Registry.lookup(Piratex.Game.Registry, game_id)

      state = GenServer.call(pid, :get_state)

      assert is_map(state)
      assert state.id == game_id
      assert state.status == :waiting
      assert is_list(state.players)
      refute Map.has_key?(state, :letter_pool) == false
    end
  end

  describe "Turn advancement when player quits" do
    test "turn advances when current player quits during open challenge" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["t", "e", "s", "t", "s"],
          center_sorted: ["e", "s", "s", "t", "t"]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")
      :ok = Game.join_game(game_id, "player3", "token3")

      :ok = Game.start_game(game_id, "token1")

      :ok = Game.claim_word(game_id, "token1", "test")

      :ok = Game.claim_word(game_id, "token2", "tests")

      :ok = Game.challenge_word(game_id, "token1", "tests")

      {:ok, %{challenges: [%{id: _challenge_id}]}} = Game.get_state(game_id)

      :ok = Game.quit_game(game_id, "token2")

      {:ok, state_after_quit} = Game.get_state(game_id)

      assert length(Enum.filter(state_after_quit.players, &(&1.status == :playing))) == 2
      assert Enum.at(state_after_quit.players, 1).status == :quit
    end
  end

  describe "Challenge vote error handling" do
    test "cannot vote on challenge in non-playing game" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      assert {:error, :game_not_playing} = Game.challenge_vote(game_id, "token1", 0, true)
    end
  end

  describe "Edge case scenarios" do
    test "rejoin after game finished still works" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["t", "e", "s", "t"],
          center_sorted: ["e", "s", "t", "t"],
          letter_pool: []
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      :ok = Game.claim_word(game_id, "token1", "test")

      :ok = Game.end_game_vote(game_id, "token1")
      :ok = Game.end_game_vote(game_id, "token2")

      :ok = Piratex.TestHelpers.wait_for_state_match(game_id, %{status: :finished})

      assert :ok = Game.rejoin_game(game_id, "player1", "token1")
    end
  end
end
