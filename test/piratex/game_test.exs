defmodule Piratex.GameTest do
  use ExUnit.Case

  alias Piratex.Game

  describe "Join Game" do
    test "game not found" do
      assert {:error, :not_found} = Game.join_game("game_id", "player1", "token1")
    end

    test "new game, 2 players join" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      {:ok, %{status: :waiting}} = Game.get_state(game_id)

      :ok = Game.join_game(game_id, "player1", "token1")

      :ok = Game.join_game(game_id, "player2", "token2")

      {:ok, %{status: :waiting, players: [_, _]}} = Game.get_state(game_id)

      :ok = Game.start_game(game_id, "token1")

      {:ok, %{status: :playing, players: [_, _]}} = Game.get_state(game_id)
    end

    test "new game max_players join and next player rejected" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()
      max_players = Piratex.Config.max_players()

      for i <- 1..max_players do
        :ok = Game.join_game(game_id, "player#{i}", "token#{i}")
      end

      assert {:error, :game_full} = Game.join_game(game_id, "player#{max_players + 1}", "token#{max_players + 1}")
    end

    test "new game player name too short" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      assert {:error, :player_name_too_short} =
        Game.join_game(game_id, String.duplicate("a", Piratex.Config.min_player_name() - 1), "token1")
    end

    test "new game player name too long" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      assert {:error, :player_name_too_long} =
        Game.join_game(game_id, String.duplicate("a", Piratex.Config.max_player_name() + 1), "token1")
    end

    test "unique player name and token" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      assert {:error, :duplicate_player} = Game.join_game(game_id, "player1", "token1")
      assert {:error, :duplicate_player} = Game.join_game(game_id, "player1", "token2")
      assert {:error, :duplicate_player} = Game.join_game(game_id, "player2", "token1")
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

      :game_already_started = Game.start_game(game_id, "token1")
      :game_already_started = Game.start_game(game_id, "token2")

      {:ok, %{status: :playing} = _state} = Game.get_state(game_id)
    end

    test "start a 2 player game - non-first player starts" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token2")

      {:ok, %{status: :playing} = _state} = Game.get_state(game_id)

      :game_already_started = Game.start_game(game_id, "token1")
      :game_already_started = Game.start_game(game_id, "token2")

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
      state = Piratex.TestHelpers.default_new_game(0, %{
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
      state = Piratex.TestHelpers.default_new_game(0, %{
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
      state = Piratex.TestHelpers.default_new_game(0, %{
        status: :waiting,
        center: ["t", "s", "e", "t"],
        center_sorted: ["e", "s", "t", "t"]
      })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      assert :ok = Game.claim_word(game_id, "token1", "set")
      assert {:ok, %{
        center: ["t"],
        players: [
          %{name: "player1"},
          %{name: "player2"}
        ],
      teams: [
        %{name: "Team-player1", words: ["set"]},
        %{name: "Team-player2", words: []}
      ]
      }} = Game.get_state(game_id)

      assert :ok = Game.claim_word(game_id, "token2", "test")
      assert {:ok, %{
        center: [],
        players: [
          %{name: "player1"},
          %{name: "player2"}
        ],
        teams: [
          %{name: "Team-player1", words: []},
          %{name: "Team-player2", words: ["test"]}
        ]
      }} = Game.get_state(game_id)
    end

    test "cannot claim recidivist word" do
      state = Piratex.TestHelpers.default_new_game(0, %{
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
      assert {:ok, %{
        center: ["s"],
        players: [
          %{name: "player1"},
          %{name: "player2"}
        ],
        teams: [
          %{name: "Team-player1", words: []},
          %{name: "Team-player2", words: ["test"]}
        ]
      }} = Game.get_state(game_id)

      assert {:error, :invalid_word} = Game.claim_word(game_id, "token2", "tests")

      assert {:ok, %{
        center: ["s"],
        players: [
          %{name: "player1"},
          %{name: "player2"}
        ],
        teams: [
          %{name: "Team-player1", words: []},
          %{name: "Team-player2", words: ["test"]}
        ]
      }} = Game.get_state(game_id)
    end
  end

  describe "Challenge Word" do
    test "game not found" do
      assert {:error, :not_found} = Game.challenge_word("game_id", "token1", "test")
    end

    test "invalid challenge" do
      state = Piratex.TestHelpers.default_new_game(0, %{
        status: :waiting,
        center: ["t", "s", "e", "t", "s"],
        center_sorted: ["e", "s", "s", "t", "t"],
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
      state = Piratex.TestHelpers.default_new_game(0, %{
        status: :waiting,
        center: ["t", "s", "e", "t", "s"],
        center_sorted: ["e", "s", "s", "t", "t"],
      })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      :ok = Game.claim_word(game_id, "token1", "test")
      assert {:ok, %{
        center: ["s"],
        players: [
          %{name: "player1"},
          %{name: "player2"}
        ],
        teams: [
          %{name: "Team-player1", words: ["test"]},
          %{name: "Team-player2"}
        ]
      }} = Game.get_state(game_id)

      :ok = Game.claim_word(game_id, "token2", "tests")

      assert :ok = Game.challenge_word(game_id, "token1", "tests")
      assert {:ok, %{
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
      assert {:error, :already_voted} = Game.challenge_vote(game_id, "token1", challenge_id, false)
      assert {:ok, %{
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
      assert {:ok, %{
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
      state = Piratex.TestHelpers.default_new_game(0, %{
        status: :waiting,
        center: ["a", "e", "t", "s"],
        center_sorted: ["a", "e", "s", "t"],
      })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      :ok = Game.claim_word(game_id, "token1", "eat")
      assert {:ok, %{
        center: ["s"],
        players: [
          %{name: "player1"},
          %{name: "player2"}
        ],
        teams: [
          %{name: "Team-player1", words: ["eat"]},
          %{name: "Team-player2", words: []}
        ]
      }} = Game.get_state(game_id)

      :ok = Game.claim_word(game_id, "token2", "east")

      assert :ok = Game.challenge_word(game_id, "token1", "east")
      assert {:ok, %{
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
      assert {:ok, %{
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
      assert {:ok, %{
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
      state = Piratex.TestHelpers.default_new_game(0, %{
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

      assert {:ok, %{status: :finished, teams: [%{name: "Team-player1", score: 3}, %{name: "Team-player2", score: 2}]}} =
        Game.get_state(game_id)
    end

    test "2 players, 1 quit" do
      state = Piratex.TestHelpers.default_new_game(0, %{
        status: :waiting,
        center: ["t", "s", "e", "t", "s", "a", "t"],
        center_sorted: ["a", "e", "s", "s", "t", "t", "t"],
        letter_pool: ["b"]
      })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      :ok = Game.quit_game(game_id, "token2")

      assert {:ok, %{status: :playing, teams: [%{name: "Team-player1", score: 0}, %{name: "Team-player2", score: 0}]}} = Game.get_state(game_id)

      assert :ok = Game.flip_letter(game_id, "token1")
      assert {:ok, %{status: :playing, letter_pool: []} = state} = Game.get_state(game_id)

      assert Piratex.Helpers.no_more_letters?(state)

      :ok = Game.end_game_vote(game_id, "token1")

      :ok = Piratex.TestHelpers.wait_for_state_match(game_id, %{status: :finished})

      assert {:ok, %{status: :finished, teams: [%{name: "Team-player1", score: 0}, %{name: "Team-player2", score: 0}]}} = Game.get_state(game_id)
    end

    test "2 players, 1 quit after 1st vote" do
      state = Piratex.TestHelpers.default_new_game(0, %{
        status: :waiting,
        center: ["t", "s", "e", "t", "s", "a", "t"],
        center_sorted: ["a", "e", "s", "s", "t", "t", "t"],
        letter_pool: ["b"]
      })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      assert {:ok, %{status: :playing, teams: [%{name: "Team-player1", score: 0}, %{name: "Team-player2", score: 0}]}} = Game.get_state(game_id)

      assert :ok = Game.flip_letter(game_id, "token1")
      assert {:ok, %{status: :playing, letter_pool: []} = state} = Game.get_state(game_id)

      assert Piratex.Helpers.no_more_letters?(state)

      :ok = Game.end_game_vote(game_id, "token1")

      :ok = Game.quit_game(game_id, "token2")


      :ok = Piratex.TestHelpers.wait_for_state_match(game_id, %{status: :finished})

      assert {:ok, %{status: :finished, teams: [%{name: "Team-player1", score: 0}, %{name: "Team-player2", score: 0}]}} = Game.get_state(game_id)
    end

    test "3 players, 1 votes then quits, then 1 votes. Do not end because 3rd person has not voted" do
      state = Piratex.TestHelpers.default_new_game(0, %{
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
      {:incorrect_state, _} = Piratex.TestHelpers.wait_for_state_match(game_id, %{status: :finished})

      :ok = Game.end_game_vote(game_id, "token3")

      :ok = Piratex.TestHelpers.wait_for_state_match(game_id, %{status: :finished})

      assert {:ok, %{status: :finished, teams: [%{name: "Team-player1", score: 2}, %{name: "Team-player2", score: 2}, %{name: "Team-player3", score: 2}]}} = Game.get_state(game_id)
    end

    test "3 players" do
      state = Piratex.TestHelpers.default_new_game(0, %{
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

      assert {:ok, %{status: :finished, teams: [%{name: "Team-player1", score: 2}, %{name: "Team-player2", score: 2}, %{name: "Team-player3", score: 2}]}} = Game.get_state(game_id)
    end

    test "3 players, 2 quit last" do
      state = Piratex.TestHelpers.default_new_game(0, %{
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

      assert {:ok, %{status: :finished, teams: [%{name: "Team-player1", score: 2}, %{name: "Team-player2", score: 2}, %{name: "Team-player3", score: 2}]}} = Game.get_state(game_id)
    end

    test "3 players, 2 quit first" do
      state = Piratex.TestHelpers.default_new_game(0, %{
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

      assert {:ok, %{status: :finished, teams: [%{name: "Team-player1", score: 2}, %{name: "Team-player2", score: 2}, %{name: "Team-player3", score: 2}]}} = Game.get_state(game_id)
    end

    test "4 players" do
      state = Piratex.TestHelpers.default_new_game(0, %{
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

      {:incorrect_state, %{end_game_votes: end_game_votes}} = Piratex.TestHelpers.wait_for_state_match(game_id, %{status: :finished})

      # assert that ONLY 2 players have voted
      assert %{"player1" => true, "player2" => true} == end_game_votes

      :ok = Game.end_game_vote(game_id, "token3")
      :ok = Game.end_game_vote(game_id, "token4")

      :ok = Piratex.TestHelpers.wait_for_state_match(game_id, %{status: :finished})

      assert {:ok, %{status: :finished, teams: [%{name: "Team-player1", score: 2}, %{name: "Team-player2", score: 2}, %{name: "Team-player3", score: 2}, %{name: "Team-player4", score: 0}]}} = Game.get_state(game_id)
    end

    test "5 players" do
      state = Piratex.TestHelpers.default_new_game(0, %{
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

      assert {:ok, %{status: :finished, teams: [%{name: "Team-player1", score: 2}, %{name: "Team-player2", score: 2}, %{name: "Team-player3", score: 2}, %{name: "Team-player4", score: 0}, %{name: "Team-player5", score: 0}]}} = Game.get_state(game_id)
    end
  end
end
