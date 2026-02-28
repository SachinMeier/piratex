defmodule Piratex.ScoreServiceTest do
  use ExUnit.Case

  alias Piratex.Team
  alias Piratex.WordSteal
  alias Piratex.ScoreService

  test "calculate_scores" do
    scores = [
      {0, []},
      {2, ["bot"]},
      {3, ["boat"]},
      {4, ["boast"]},
      {5, ["aborts"]},
      {6, ["boaters"]},
      {7, ["boasters"]},
      {8, ["saboteurs"]},
      {9, ["zoo", "ooze", "ozone"]},
      {10, ["the", "haters", "hate"]},
      {12, ["ooze", "ozone", "snooze"]},
      {15, ["doozies", "snooze", "ozone"]},
      {51,
       [
         "potteries",
         "advancer",
         "analogue",
         "plowing",
         "renown",
         "juicy",
         "golfs",
         "need",
         "joey",
         "axe",
         "him"
       ]},
      {62,
       [
         "flittering",
         "tolerates",
         "dousers",
         "thanked",
         "biome",
         "brims",
         "quark",
         "vapid",
         "quiz",
         "cave",
         "iota",
         "afar",
         "doth",
         "web"
       ]}
    ]

    Enum.each(scores, fn {score, words} ->
      team = Team.new("name", words)
      state = ScoreService.calculate_team_scores(%{teams: [team]})

      assert %{teams: [%{score: ^score}]} = state
    end)
  end

  describe "get_letter_pairs" do
    test "returns empty list for nil" do
      assert ScoreService.get_letter_pairs(nil) == []
    end

    test "returns empty list for single character" do
      assert ScoreService.get_letter_pairs("a") == []
    end

    test "returns one pair for two character word" do
      assert ScoreService.get_letter_pairs("ab") == [{"a", "b"}]
    end

    test "returns consecutive letter pairs for longer words" do
      pairs = ScoreService.get_letter_pairs("cat")
      assert {"c", "a"} in pairs
      assert {"a", "t"} in pairs
      assert length(pairs) == 2
    end

    test "returns all consecutive pairs for a five letter word" do
      pairs = ScoreService.get_letter_pairs("hello")
      assert {"h", "e"} in pairs
      assert {"e", "l"} in pairs
      assert {"l", "l"} in pairs
      assert {"l", "o"} in pairs
      assert length(pairs) == 4
    end

    test "returns empty list for empty string" do
      assert ScoreService.get_letter_pairs("") == []
    end
  end

  describe "calculate_team_stats" do
    test "single team with words" do
      teams = [
        %{id: 0, name: "team1", score: 10, words: ["boat", "goats", "zoo"]}
      ]

      stats = ScoreService.calculate_team_stats(teams)

      assert stats.total_score == 10
      assert stats.word_count == 3
      assert stats.word_length_distribution == %{4 => 1, 5 => 1, 3 => 1}
      assert stats.margin_of_victory == 0
      assert stats.avg_points_per_word == %{0 => 10 / 3}
    end

    test "two teams with different scores" do
      teams = [
        %{id: 0, name: "team1", score: 12, words: ["boat", "goats", "zoo"]},
        %{id: 1, name: "team2", score: 5, words: ["cat", "bat"]}
      ]

      stats = ScoreService.calculate_team_stats(teams)

      assert stats.total_score == 17
      assert stats.word_count == 5
      assert stats.margin_of_victory == 7
      assert stats.avg_points_per_word == %{0 => 12 / 3, 1 => 5 / 2}
    end

    test "team with no words" do
      teams = [
        %{id: 0, name: "team1", score: 0, words: []}
      ]

      stats = ScoreService.calculate_team_stats(teams)

      assert stats.total_score == 0
      assert stats.word_count == 0
      assert stats.word_length_distribution == %{}
      assert stats.avg_word_length == 0
      assert stats.avg_points_per_word == %{0 => 0}
      assert stats.margin_of_victory == 0
    end

    test "two teams both empty" do
      teams = [
        %{id: 0, name: "team1", score: 0, words: []},
        %{id: 1, name: "team2", score: 0, words: []}
      ]

      stats = ScoreService.calculate_team_stats(teams)

      assert stats.total_score == 0
      assert stats.word_count == 0
      assert stats.margin_of_victory == 0
      assert stats.avg_word_length == 0
    end

    test "avg_word_length calculation" do
      # avg_word_length = (total_score + word_count) / word_count
      # With words ["boat", "goats"] on one team with score 7:
      # total_score=7, word_count=2, avg = (7 + 2) / 2 = 4.5
      teams = [
        %{id: 0, name: "team1", score: 7, words: ["boat", "goats"]}
      ]

      stats = ScoreService.calculate_team_stats(teams)

      assert stats.avg_word_length == (7 + 2) / 2
    end
  end

  describe "calculate_game_stats" do
    test "simple stats" do
      t = DateTime.utc_now()
      duration_s = 1000

      state = %{
        status: :finished,
        center: [],
        start_time: DateTime.add(t, -duration_s, :second),
        end_time: t,
        center_sorted: [],
        past_challenges: [],
        teams: [
          %{
            id: 0,
            name: "team1",
            score: 0,
            words: ["bet", "baste", "bit"]
          },
          %{
            id: 1,
            name: "team2",
            score: 0,
            words: ["set", "sat"]
          }
        ],
        players: [
          %{
            name: "player1",
            team_id: 0,
            score: 0
          },
          %{
            name: "player2",
            team_id: 1,
            score: 0
          }
        ],
        players_teams: %{0 => 0, 1 => 1},
        history: [
          %{
            thief_word: "set",
            thief_team_idx: 1,
            thief_player_idx: 1,
            victim_word: nil,
            victim_team_idx: nil,
            letter_count: 100
          },
          %{
            thief_word: "bet",
            thief_team_idx: 0,
            thief_player_idx: 0,
            victim_word: nil,
            victim_team_idx: nil,
            letter_count: 99
          },
          %{
            thief_word: "baste",
            thief_team_idx: 0,
            thief_player_idx: 0,
            victim_word: nil,
            victim_team_idx: nil,
            letter_count: 91
          },
          %{
            thief_word: "sat",
            thief_team_idx: 1,
            thief_player_idx: 1,
            victim_word: nil,
            victim_team_idx: nil,
            letter_count: 34
          },
          %{
            thief_word: "bit",
            thief_team_idx: 0,
            thief_player_idx: 0,
            victim_word: nil,
            victim_team_idx: nil,
            letter_count: 22
          }
        ]
      }

      state = ScoreService.calculate_game_stats(state)

      assert state.game_stats.game_duration == duration_s
      assert state.game_stats.total_steals == 5

      assert %{
               thief_word: "baste",
               thief_player_idx: 0
             } = state.game_stats.best_steal

      assert state.game_stats.raw_player_stats == %{
               0 => %{
                 points: 8,
                 words: ["bet", "baste", "bit"],
                 steals: 3,
                 points_per_steal: 8 / 3
               },
               1 => %{
                 points: 4,
                 words: ["set", "sat"],
                 steals: 2,
                 points_per_steal: 2
               }
             }

      assert state.game_stats.raw_mvp == %{
               player_idx: 0,
               points: 8,
               words: ["bet", "baste", "bit"],
               steals: 3,
               points_per_steal: 8 / 3
             }

      assert state.game_stats.challenge_stats == %{
               count: 0,
               valid_ct: 0,
               player_stats: %{},
               invalid_word_steals: []
             }

      # Score timeline: history sorted by letter_count ascending
      # lc=22: team 0 steals "bit" from center -> team 0: +2 (score: 2)
      # lc=34: team 1 steals "sat" from center -> team 1: +2 (score: 2)
      # lc=91: team 0 steals "baste" from center -> team 0: +4 (score: 6)
      # lc=99: team 0 steals "bet" from center -> team 0: +2 (score: 8)
      # lc=100: team 1 steals "set" from center -> team 1: +2 (score: 4)
      assert state.game_stats.score_timeline == %{
               0 => [{0, 0}, {22, 2}, {91, 6}, {99, 8}],
               1 => [{0, 0}, {34, 2}, {100, 4}]
             }

      assert state.game_stats.score_timeline_max == 8
    end

    test "test heatmap stats" do
      history = [
        %Piratex.WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "aqua",
          letter_count: 79
        },
        %Piratex.WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "bee",
          letter_count: 73
        },
        %Piratex.WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "grog",
          letter_count: 73
        },
        %Piratex.WordSteal{
          victim_team_idx: 0,
          victim_word: "come",
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cameo",
          letter_count: 70
        },
        %Piratex.WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "come",
          letter_count: 70
        },
        %Piratex.WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "found",
          letter_count: 64
        },
        %Piratex.WordSteal{
          victim_team_idx: 0,
          victim_word: "hike",
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "hiker",
          letter_count: 64
        },
        %Piratex.WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "hike",
          letter_count: 64
        },
        %Piratex.WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "pain",
          letter_count: 61
        },
        %Piratex.WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "flop",
          letter_count: 61
        },
        %Piratex.WordSteal{
          victim_team_idx: 0,
          victim_word: "touter",
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "touters",
          letter_count: 61
        },
        %Piratex.WordSteal{
          victim_team_idx: 0,
          victim_word: "outer",
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "touter",
          letter_count: 61
        },
        %Piratex.WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "outer",
          letter_count: 61
        },
        %Piratex.WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "stir",
          letter_count: 61
        },
        %Piratex.WordSteal{
          victim_team_idx: 0,
          victim_word: "and",
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "wand",
          letter_count: 33
        },
        %Piratex.WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "and",
          letter_count: 33
        },
        %Piratex.WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "boy",
          letter_count: 33
        },
        %Piratex.WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "wilt",
          letter_count: 33
        },
        %Piratex.WordSteal{
          victim_team_idx: 0,
          victim_word: "hard",
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "haired",
          letter_count: 33
        },
        %Piratex.WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "hard",
          letter_count: 33
        },
        %Piratex.WordSteal{
          victim_team_idx: 0,
          victim_word: "steal",
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cleats",
          letter_count: 15
        },
        %Piratex.WordSteal{
          victim_team_idx: 0,
          victim_word: "tale",
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "steal",
          letter_count: 11
        },
        %Piratex.WordSteal{
          victim_team_idx: 0,
          victim_word: "eat",
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "tale",
          letter_count: 7
        },
        %Piratex.WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "eat",
          letter_count: 7
        }
      ]

      state = %{
        history: history,
        teams: [
          %{
            id: 0,
            name: "team1",
            score: 0,
            words: ["bet", "baste", "bit"]
          },
          %{
            id: 1,
            name: "team2",
            score: 0,
            words: ["set", "sat"]
          }
        ],
        players: [
          %{
            name: "player1",
            team_id: 0,
            score: 0
          },
          %{
            name: "player2",
            team_id: 1,
            score: 0
          }
        ],
        players_teams: %{0 => 0, 1 => 1}
      }

      %{heatmap: heatmap, heatmap_max: heatmap_max} =
        ScoreService.calculate_history_stats(state, history)

      assert heatmap == %{
               7 => 7,
               11 => 5,
               15 => 6,
               33 => 24,
               61 => 30,
               64 => 14,
               70 => 9,
               73 => 7,
               79 => 4
             }

      assert heatmap_max == 30
    end

    test "steal from another word" do
      # Team 0 player 0 steals "cat" from center, then Team 1 player 1 steals
      # "cart" from team 0's "cat" (cross-team steal).
      # Cross-team steal: full word points for the thief = len("cart") - 1 = 3
      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cat",
          letter_count: 80
        },
        %WordSteal{
          victim_team_idx: 0,
          victim_word: "cat",
          thief_team_idx: 1,
          thief_player_idx: 1,
          thief_word: "cart",
          letter_count: 90
        }
      ]

      state = %{
        status: :finished,
        center: [],
        center_sorted: [],
        start_time: ~U[2025-01-01 00:00:00Z],
        end_time: ~U[2025-01-01 00:10:00Z],
        past_challenges: [],
        teams: [
          %{id: 0, name: "team1", score: 0, words: []},
          %{id: 1, name: "team2", score: 3, words: ["cart"]}
        ],
        players: [
          %{name: "player1", team_id: 0, score: 0},
          %{name: "player2", team_id: 1, score: 0}
        ],
        players_teams: %{0 => 0, 1 => 1},
        history: history
      }

      state = ScoreService.calculate_game_stats(state)
      stats = state.game_stats

      # Player 0: stole "cat" from center => word_points("cat") = 3 - 1 = 2
      assert stats.raw_player_stats[0].points == 2
      assert stats.raw_player_stats[0].words == ["cat"]
      assert stats.raw_player_stats[0].steals == 1

      # Player 1: cross-team steal "cart" from team 0's "cat"
      # Cross-team steal => full word points = len("cart") - 1 = 3
      assert stats.raw_player_stats[1].points == 3
      assert stats.raw_player_stats[1].words == ["cart"]
      assert stats.raw_player_stats[1].steals == 1

      assert stats.total_steals == 2
    end

    test "steal from same team" do
      # Team 0 player 0 steals "cat" from center, then player 0 steals own
      # team's "cat" to make "cats" (self-steal / same-team steal).
      # Self-steal: only the delta letters are counted = len("cats") - len("cat") = 1
      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cat",
          letter_count: 80
        },
        %WordSteal{
          victim_team_idx: 0,
          victim_word: "cat",
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cats",
          letter_count: 90
        }
      ]

      state = %{
        status: :finished,
        center: [],
        center_sorted: [],
        start_time: ~U[2025-01-01 00:00:00Z],
        end_time: ~U[2025-01-01 00:10:00Z],
        past_challenges: [],
        teams: [
          %{id: 0, name: "team1", score: 3, words: ["cats"]},
          %{id: 1, name: "team2", score: 0, words: []}
        ],
        players: [
          %{name: "player1", team_id: 0, score: 0},
          %{name: "player2", team_id: 1, score: 0}
        ],
        players_teams: %{0 => 0, 1 => 1},
        history: history
      }

      state = ScoreService.calculate_game_stats(state)
      stats = state.game_stats

      # Player 0:
      #   "cat" from center: letters_added = 3 (from center), word_points = 3 - 1 = 2
      #     (center steals: thief_team_idx != victim_team_idx? victim_team_idx is nil,
      #      so thief_team_idx(0) == victim_team_idx(nil) is false => full word points = 2)
      #   Wait, victim_team_idx is nil for center steals. 0 == nil is false, so it's treated
      #   as a cross-team steal giving full word_points. Let me re-check:
      #   word_steal_points = if thief_team_idx == victim_team_idx -> delta, else -> word_points
      #   For center steal: 0 == nil => false => word_points("cat") = 2
      #   For self-steal: 0 == 0 => true => delta = len("cats") - len("cat") = 1
      #   Total: 2 + 1 = 3
      assert stats.raw_player_stats[0].points == 3
      assert Enum.sort(stats.raw_player_stats[0].words) == ["cat", "cats"]
      assert stats.raw_player_stats[0].steals == 2

      # Player 1: no actions
      assert stats.raw_player_stats[1].points == 0
      assert stats.raw_player_stats[1].steals == 0

      assert stats.total_steals == 2
    end

    test "failed challenges are filtered out" do
      # "cats" was played but then challenged and result=false (challenge succeeded,
      # word is invalid). "cats" should be excluded from valid_history stats.
      cats_steal = %WordSteal{
        victim_team_idx: 0,
        victim_word: "cat",
        thief_team_idx: 1,
        thief_player_idx: 1,
        thief_word: "cats",
        letter_count: 90
      }

      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cat",
          letter_count: 80
        },
        cats_steal,
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "dog",
          letter_count: 95
        }
      ]

      past_challenges = [
        %{
          id: 1,
          word_steal: cats_steal,
          votes: %{"player1" => false, "player2" => false},
          result: false
        }
      ]

      state = %{
        status: :finished,
        center: [],
        center_sorted: [],
        start_time: ~U[2025-01-01 00:00:00Z],
        end_time: ~U[2025-01-01 00:10:00Z],
        past_challenges: past_challenges,
        teams: [
          %{id: 0, name: "team1", score: 4, words: ["cat", "dog"]},
          %{id: 1, name: "team2", score: 0, words: []}
        ],
        players: [
          %{name: "player1", team_id: 0, score: 0},
          %{name: "player2", team_id: 1, score: 0}
        ],
        players_teams: %{0 => 0, 1 => 1},
        history: history
      }

      state = ScoreService.calculate_game_stats(state)
      stats = state.game_stats

      # "cats" should be filtered out. Only "cat" and "dog" remain in valid history.
      # Player 0: "cat" (center, word_points=2) + "dog" (center, word_points=2) = 4
      assert stats.raw_player_stats[0].points == 4
      assert stats.raw_player_stats[0].steals == 2
      assert "cat" in stats.raw_player_stats[0].words
      assert "dog" in stats.raw_player_stats[0].words

      # Player 1: "cats" was filtered out, so 0 points
      assert stats.raw_player_stats[1].points == 0
      assert stats.raw_player_stats[1].steals == 0

      # The challenge stats should still show the failed challenge
      assert stats.challenge_stats.count == 1
      assert stats.challenge_stats.valid_ct == 0
      assert length(stats.challenge_stats.invalid_word_steals) == 1

      # total_steals only counts valid history entries
      assert stats.total_steals == 2
    end

    test "word is stolen multiple times" do
      # "eat" from center -> team 0 player 0
      # team 1 player 1 steals "eat" -> "eats" (cross-team)
      # team 0 player 0 steals "eats" -> "feast" (cross-team)
      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "eat",
          letter_count: 70
        },
        %WordSteal{
          victim_team_idx: 0,
          victim_word: "eat",
          thief_team_idx: 1,
          thief_player_idx: 1,
          thief_word: "eats",
          letter_count: 80
        },
        %WordSteal{
          victim_team_idx: 1,
          victim_word: "eats",
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "feast",
          letter_count: 90
        }
      ]

      state = %{
        status: :finished,
        center: [],
        center_sorted: [],
        start_time: ~U[2025-01-01 00:00:00Z],
        end_time: ~U[2025-01-01 00:10:00Z],
        past_challenges: [],
        teams: [
          %{id: 0, name: "team1", score: 4, words: ["feast"]},
          %{id: 1, name: "team2", score: 0, words: []}
        ],
        players: [
          %{name: "player1", team_id: 0, score: 0},
          %{name: "player2", team_id: 1, score: 0}
        ],
        players_teams: %{0 => 0, 1 => 1},
        history: history
      }

      state = ScoreService.calculate_game_stats(state)
      stats = state.game_stats

      # Player 0:
      #   "eat" from center: 0 != nil => cross-team path => word_points("eat") = 2
      #   "feast" from team 1: 0 != 1 => cross-team => word_points("feast") = 4
      #   Total: 2 + 4 = 6
      assert stats.raw_player_stats[0].points == 6
      assert stats.raw_player_stats[0].steals == 2
      assert "eat" in stats.raw_player_stats[0].words
      assert "feast" in stats.raw_player_stats[0].words

      # Player 1:
      #   "eats" from team 0: 1 != 0 => cross-team => word_points("eats") = 3
      assert stats.raw_player_stats[1].points == 3
      assert stats.raw_player_stats[1].steals == 1
      assert stats.raw_player_stats[1].words == ["eats"]

      assert stats.total_steals == 3
    end

    test "4 players on 2 teams" do
      # Team 0: player 0 and player 2
      # Team 1: player 1 and player 3
      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "bat",
          letter_count: 70
        },
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 1,
          thief_player_idx: 1,
          thief_word: "dog",
          letter_count: 75
        },
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 2,
          thief_word: "run",
          letter_count: 80
        },
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 1,
          thief_player_idx: 3,
          thief_word: "fox",
          letter_count: 85
        },
        # Player 2 self-steals own team's "bat" -> "bats"
        %WordSteal{
          victim_team_idx: 0,
          victim_word: "bat",
          thief_team_idx: 0,
          thief_player_idx: 2,
          thief_word: "bats",
          letter_count: 90
        },
        # Player 3 cross-steals team 0's "run" -> "rung"
        %WordSteal{
          victim_team_idx: 0,
          victim_word: "run",
          thief_team_idx: 1,
          thief_player_idx: 3,
          thief_word: "rung",
          letter_count: 95
        }
      ]

      state = %{
        status: :finished,
        center: [],
        center_sorted: [],
        start_time: ~U[2025-01-01 00:00:00Z],
        end_time: ~U[2025-01-01 00:15:00Z],
        past_challenges: [],
        teams: [
          %{id: 0, name: "team1", score: 3, words: ["bats"]},
          %{id: 1, name: "team2", score: 7, words: ["dog", "fox", "rung"]}
        ],
        players: [
          %{name: "player1", team_id: 0, score: 0},
          %{name: "player2", team_id: 1, score: 0},
          %{name: "player3", team_id: 0, score: 0},
          %{name: "player4", team_id: 1, score: 0}
        ],
        players_teams: %{0 => 0, 1 => 1, 2 => 0, 3 => 1},
        history: history
      }

      state = ScoreService.calculate_game_stats(state)
      stats = state.game_stats

      # Player 0: "bat" from center => word_points("bat") = 2
      assert stats.raw_player_stats[0].points == 2
      assert stats.raw_player_stats[0].steals == 1
      assert stats.raw_player_stats[0].words == ["bat"]

      # Player 1: "dog" from center => word_points("dog") = 2
      assert stats.raw_player_stats[1].points == 2
      assert stats.raw_player_stats[1].steals == 1
      assert stats.raw_player_stats[1].words == ["dog"]

      # Player 2: "run" from center => word_points("run") = 2,
      #           "bats" self-steal from "bat" => delta = 4 - 3 = 1
      #           Total: 2 + 1 = 3
      assert stats.raw_player_stats[2].points == 3
      assert stats.raw_player_stats[2].steals == 2
      assert "run" in stats.raw_player_stats[2].words
      assert "bats" in stats.raw_player_stats[2].words

      # Player 3: "fox" from center => word_points("fox") = 2,
      #           "rung" cross-steal from team 0's "run" => word_points("rung") = 3
      #           Total: 2 + 3 = 5
      assert stats.raw_player_stats[3].points == 5
      assert stats.raw_player_stats[3].steals == 2
      assert "fox" in stats.raw_player_stats[3].words
      assert "rung" in stats.raw_player_stats[3].words

      # All 4 players tracked individually
      assert map_size(stats.raw_player_stats) == 4
      assert stats.total_steals == 6

      # MVP should be player 3 with 5 points
      assert stats.raw_mvp.player_idx == 3
      assert stats.raw_mvp.points == 5

      assert stats.game_duration == 900
    end
  end

  describe "calculate_history_stats" do
    test "score_timeline with cross-team steals" do
      # Team 0 takes "cat" from center at lc=10
      # Team 1 steals "cat" -> "cart" (cross-team) at lc=20
      # Expected timeline:
      #   team 0: [{0,0}, {10, 2}, {20, 0}] (gains 2, then loses 2 from cross-team steal)
      #   team 1: [{0,0}, {20, 3}] (gains word_points("cart") = 3)
      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cat",
          letter_count: 10
        },
        %WordSteal{
          victim_team_idx: 0,
          victim_word: "cat",
          thief_team_idx: 1,
          thief_player_idx: 1,
          thief_word: "cart",
          letter_count: 20
        }
      ]

      state = %{
        teams: [
          %{id: 0, name: "team1", score: 0, words: []},
          %{id: 1, name: "team2", score: 3, words: ["cart"]}
        ],
        players: [
          %{name: "player1", team_id: 0, score: 0},
          %{name: "player2", team_id: 1, score: 0}
        ],
        players_teams: %{0 => 0, 1 => 1}
      }

      result = ScoreService.calculate_history_stats(state, history)

      # Cross-team steal score changes:
      # lc=10: team 0 steals "cat" from center => +2 for team 0
      # lc=20: team 1 steals "cart" from team 0's "cat"
      #   thief (team 1): +word_points("cart") = +3
      #   victim (team 0): -word_points("cat") = -2
      assert result.score_timeline == %{
               0 => [{0, 0}, {10, 2}, {20, 0}],
               1 => [{0, 0}, {20, 3}]
             }

      assert result.score_timeline_max == 3
    end

    test "score_timeline with same-team steal" do
      # Team 0 takes "cat" from center at lc=10
      # Team 0 self-steals "cat" -> "cats" at lc=20
      # Self-steal score change: len("cats") - len("cat") = 1
      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cat",
          letter_count: 10
        },
        %WordSteal{
          victim_team_idx: 0,
          victim_word: "cat",
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cats",
          letter_count: 20
        }
      ]

      state = %{
        teams: [
          %{id: 0, name: "team1", score: 3, words: ["cats"]},
          %{id: 1, name: "team2", score: 0, words: []}
        ],
        players: [
          %{name: "player1", team_id: 0, score: 0},
          %{name: "player2", team_id: 1, score: 0}
        ],
        players_teams: %{0 => 0, 1 => 1}
      }

      result = ScoreService.calculate_history_stats(state, history)

      # lc=10: "cat" from center => team 0: +2 (score: 2)
      # lc=20: "cats" self-steal => team 0: +(4-3) = +1 (score: 3)
      assert result.score_timeline == %{
               0 => [{0, 0}, {10, 2}, {20, 3}],
               1 => [{0, 0}]
             }

      assert result.score_timeline_max == 3
    end

    test "score deltas with multiple cross-team steals" do
      # Team 0 takes "dog" from center at lc=5
      # Team 1 takes "fox" from center at lc=10
      # Team 0 steals "fox" -> "foxes" (cross-team) at lc=15
      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "dog",
          letter_count: 5
        },
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 1,
          thief_player_idx: 1,
          thief_word: "fox",
          letter_count: 10
        },
        %WordSteal{
          victim_team_idx: 1,
          victim_word: "fox",
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "foxes",
          letter_count: 15
        }
      ]

      state = %{
        teams: [
          %{id: 0, name: "team1", score: 6, words: ["dog", "foxes"]},
          %{id: 1, name: "team2", score: 0, words: []}
        ],
        players: [
          %{name: "player1", team_id: 0, score: 0},
          %{name: "player2", team_id: 1, score: 0}
        ],
        players_teams: %{0 => 0, 1 => 1}
      }

      result = ScoreService.calculate_history_stats(state, history)

      # lc=5: team 0 "dog" from center => +2, team 0 score: 2
      # lc=10: team 1 "fox" from center => +2, team 1 score: 2
      # lc=15: team 0 steals "fox" -> "foxes" cross-team
      #   team 0: +word_points("foxes") = +4, team 0 score: 6
      #   team 1: -word_points("fox") = -2, team 1 score: 0
      assert result.score_timeline == %{
               0 => [{0, 0}, {5, 2}, {15, 6}],
               1 => [{0, 0}, {10, 2}, {15, 0}]
             }

      assert result.score_timeline_max == 6
    end

    test "empty history returns zeroed stats" do
      state = %{
        teams: [
          %{id: 0, name: "team1", score: 0, words: []}
        ],
        players: [
          %{name: "player1", team_id: 0, score: 0}
        ],
        players_teams: %{0 => 0}
      }

      result = ScoreService.calculate_history_stats(state, [])

      assert result.total_steals == 0

      assert result.raw_player_stats == %{
               0 => %{points: 0, words: [], steals: 0, points_per_steal: 0}
             }

      assert result.heatmap == %{}
      assert result.heatmap_max == 0
      assert result.score_timeline == %{0 => [{0, 0}]}
      assert result.score_timeline_max == 0
    end

    test "longest_word is tracked" do
      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cat",
          letter_count: 10
        },
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "elephant",
          letter_count: 20
        },
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "dog",
          letter_count: 30
        }
      ]

      state = %{
        teams: [%{id: 0, name: "team1", score: 0, words: []}],
        players: [%{name: "player1", team_id: 0, score: 0}],
        players_teams: %{0 => 0}
      }

      result = ScoreService.calculate_history_stats(state, history)

      assert result.longest_word == "elephant"
      assert result.longest_word_length == 8
    end
  end

  describe "calculate_game_stats edge cases" do
    test "nil end_time results in zero duration" do
      state = %{
        status: :finished,
        center: [],
        center_sorted: [],
        start_time: ~U[2025-01-01 00:00:00Z],
        end_time: nil,
        past_challenges: [],
        teams: [
          %{id: 0, name: "team1", score: 0, words: []}
        ],
        players: [
          %{name: "player1", team_id: 0, score: 0}
        ],
        players_teams: %{0 => 0},
        history: []
      }

      state = ScoreService.calculate_game_stats(state)
      assert state.game_stats.game_duration == 0
    end

    test "nil start_time results in zero duration" do
      state = %{
        status: :finished,
        center: [],
        center_sorted: [],
        start_time: nil,
        end_time: ~U[2025-01-01 00:10:00Z],
        past_challenges: [],
        teams: [
          %{id: 0, name: "team1", score: 0, words: []}
        ],
        players: [
          %{name: "player1", team_id: 0, score: 0}
        ],
        players_teams: %{0 => 0},
        history: []
      }

      state = ScoreService.calculate_game_stats(state)
      assert state.game_stats.game_duration == 0
    end

    test "mvp defaults to first player when no steals" do
      state = %{
        status: :finished,
        center: [],
        center_sorted: [],
        start_time: ~U[2025-01-01 00:00:00Z],
        end_time: ~U[2025-01-01 00:10:00Z],
        past_challenges: [],
        teams: [
          %{id: 0, name: "team1", score: 0, words: []}
        ],
        players: [
          %{name: "player1", team_id: 0, score: 0}
        ],
        players_teams: %{0 => 0},
        history: []
      }

      state = ScoreService.calculate_game_stats(state)

      # When all players have 0 points, max_by picks the first one
      assert state.game_stats.raw_mvp.player_idx == 0
      assert state.game_stats.raw_mvp.points == 0
    end
  end

  describe "calculate_challenge_stats" do
    test "simple stats" do
      cases = [
        %{
          count: 0,
          valid_ct: 0,
          player_stats: %{},
          invalid_word_steals: [],
          past_challenges: []
        },
        %{
          count: 1,
          valid_ct: 1,
          player_stats: %{0 => %{count: 1, valid_ct: 1}},
          invalid_word_steals: [],
          past_challenges: [
            %{
              id: 1,
              word_steal: %{
                thief_word: "set",
                thief_player_idx: 0,
                victim_word: "test",
                victim_team_idx: 1
              },
              votes: %{
                "Player 1" => true,
                "Player 2" => false
              },
              result: true,
              timeout_ref: nil
            }
          ]
        },
        %{
          count: 4,
          valid_ct: 2,
          player_stats: %{0 => %{count: 2, valid_ct: 1}, 1 => %{count: 2, valid_ct: 1}},
          invalid_word_steals: ["cats", "tests"],
          past_challenges: [
            %{
              id: 1,
              word_steal: %{
                thief_word: "tests",
                thief_player_idx: 0,
                victim_word: "test",
                victim_team_idx: 1
              },
              votes: %{
                "Player 1" => true,
                "Player 2" => false,
                "Player 3" => false,
                "Player 4" => false
              },
              result: false
            },
            %{
              id: 2,
              word_steal: %{
                thief_word: "testes",
                thief_player_idx: 0,
                victim_word: "test",
                victim_team_idx: 1
              },
              votes: %{
                "Player 1" => true,
                "Player 2" => true,
                "Player 3" => true,
                "Player 4" => true
              },
              result: true
            },
            %{
              id: 3,
              word_steal: %{
                thief_word: "cats",
                thief_player_idx: 1,
                victim_word: "cat",
                victim_team_idx: 1
              },
              votes: %{
                "Player 1" => true,
                "Player 2" => false,
                "Player 3" => false,
                "Player 4" => false
              },
              result: false
            },
            %{
              id: 4,
              word_steal: %{
                thief_word: "cast",
                thief_player_idx: 1,
                victim_word: "cat",
                victim_team_idx: 1
              },
              votes: %{
                "Player 1" => true,
                "Player 2" => true,
                "Player 3" => true,
                "Player 4" => false
              },
              result: true
            }
          ]
        }
      ]

      Enum.each(cases, fn c ->
        stats = ScoreService.calculate_challenge_stats(c.past_challenges)
        assert stats.count == c.count
        assert stats.valid_ct == c.valid_ct
        assert stats.player_stats == c.player_stats

        invalid_words = Enum.map(stats.invalid_word_steals, fn w -> w.thief_word end)

        for word <- c.invalid_word_steals do
          assert word in invalid_words
        end
      end)
    end
  end

  describe "calculate_best_steal_score" do
    test "word steals" do
      steals = [
        %{
          victim_word: "test",
          thief_word: "tests",
          score: 10
        },
        %{
          victim_word: nil,
          thief_word: "test",
          score: 7
        },
        %{
          victim_word: "act",
          thief_word: "cast",
          score: 10
        },
        %{
          victim_word: "cat",
          thief_word: "cast",
          score: 9
        },
        %{
          victim_word: "cast",
          thief_word: "stack",
          score: 12
        },
        %{
          victim_word: "quote",
          thief_word: "toques",
          score: 15
        }
      ]

      Enum.each(steals, fn s ->
        assert ScoreService.calculate_best_steal_score(s.victim_word, s.thief_word) == s.score
      end)
    end

    test "both nil" do
      assert ScoreService.calculate_best_steal_score(nil, nil) == 0
    end
  end

  describe "calculate_margin_of_victory edge cases" do
    test "tied teams have zero margin" do
      teams = [
        %{id: 0, name: "team1", score: 10, words: ["cat", "dog"]},
        %{id: 1, name: "team2", score: 10, words: ["fox", "bat"]}
      ]

      stats = ScoreService.calculate_team_stats(teams)
      assert stats.margin_of_victory == 0
    end

    test "three-way tie" do
      teams = [
        %{id: 0, name: "team1", score: 5, words: ["cat"]},
        %{id: 1, name: "team2", score: 5, words: ["dog"]},
        %{id: 2, name: "team3", score: 5, words: ["fox"]}
      ]

      stats = ScoreService.calculate_team_stats(teams)
      assert stats.margin_of_victory == 0
    end

    test "single team" do
      teams = [
        %{id: 0, name: "team1", score: 10, words: ["cat"]}
      ]

      stats = ScoreService.calculate_team_stats(teams)
      assert stats.margin_of_victory == 0
    end

    test "large margin between teams" do
      teams = [
        %{id: 0, name: "team1", score: 100, words: []},
        %{id: 1, name: "team2", score: 5, words: []}
      ]

      stats = ScoreService.calculate_team_stats(teams)
      assert stats.margin_of_victory == 95
    end
  end

  describe "calculate_avg_points_per_word edge cases" do
    test "all teams empty" do
      teams = [
        %{id: 0, name: "team1", score: 0, words: []},
        %{id: 1, name: "team2", score: 0, words: []},
        %{id: 2, name: "team3", score: 0, words: []}
      ]

      stats = ScoreService.calculate_team_stats(teams)
      assert stats.avg_points_per_word == %{0 => 0, 1 => 0, 2 => 0}
    end

    test "mixed empty and non-empty teams" do
      teams = [
        %{id: 0, name: "team1", score: 10, words: ["cat", "dog"]},
        %{id: 1, name: "team2", score: 0, words: []},
        %{id: 2, name: "team3", score: 6, words: ["fox"]}
      ]

      stats = ScoreService.calculate_team_stats(teams)
      assert stats.avg_points_per_word == %{0 => 5.0, 1 => 0, 2 => 6.0}
    end

    test "single word teams" do
      teams = [
        %{id: 0, name: "team1", score: 2, words: ["cat"]},
        %{id: 1, name: "team2", score: 5, words: ["banana"]}
      ]

      stats = ScoreService.calculate_team_stats(teams)
      assert stats.avg_points_per_word == %{0 => 2.0, 1 => 5.0}
    end
  end

  describe "calculate_avg_word_length edge cases" do
    test "zero words results in zero average" do
      teams = [
        %{id: 0, name: "team1", score: 0, words: []}
      ]

      stats = ScoreService.calculate_team_stats(teams)
      assert stats.avg_word_length == 0
    end

    test "single three-letter word" do
      teams = [
        %{id: 0, name: "team1", score: 2, words: ["cat"]}
      ]

      stats = ScoreService.calculate_team_stats(teams)
      assert stats.avg_word_length == 3.0
    end

    test "multiple teams combined stats" do
      teams = [
        %{id: 0, name: "team1", score: 7, words: ["boat", "goats"]},
        %{id: 1, name: "team2", score: 4, words: ["cat", "dog"]}
      ]

      stats = ScoreService.calculate_team_stats(teams)
      total_letters = 4 + 5 + 3 + 3
      word_count = 4
      expected_avg = total_letters / word_count
      assert stats.avg_word_length == expected_avg
    end
  end

  describe "word_length_distribution comprehensive" do
    test "various word lengths in distribution" do
      teams = [
        %{
          id: 0,
          name: "team1",
          score: 0,
          words: ["cat", "dog", "boat", "goats", "banana", "elephant"]
        }
      ]

      stats = ScoreService.calculate_team_stats(teams)
      assert stats.word_length_distribution == %{
               3 => 2,
               4 => 1,
               5 => 1,
               6 => 1,
               8 => 1
             }
    end

    test "multiple words of same length" do
      teams = [
        %{
          id: 0,
          name: "team1",
          score: 0,
          words: ["cat", "dog", "fox", "bat", "rat"]
        }
      ]

      stats = ScoreService.calculate_team_stats(teams)
      assert stats.word_length_distribution == %{3 => 5}
    end

    test "distribution across multiple teams" do
      teams = [
        %{id: 0, name: "team1", score: 0, words: ["cat", "dog"]},
        %{id: 1, name: "team2", score: 0, words: ["boat", "fox"]}
      ]

      stats = ScoreService.calculate_team_stats(teams)
      assert stats.word_length_distribution == %{3 => 3, 4 => 1}
    end

    test "very long words" do
      teams = [
        %{
          id: 0,
          name: "team1",
          score: 0,
          words: ["antidisestablishmentarianism"]
        }
      ]

      stats = ScoreService.calculate_team_stats(teams)
      assert stats.word_length_distribution == %{28 => 1}
    end
  end

  describe "score_change calculation paths" do
    test "center steal creates positive delta" do
      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "banana",
          letter_count: 10
        }
      ]

      state = %{
        teams: [%{id: 0, name: "team1", score: 0, words: []}],
        players: [%{name: "player1", team_id: 0, score: 0}],
        players_teams: %{0 => 0}
      }

      result = ScoreService.calculate_history_stats(state, history)
      assert result.score_timeline[0] == [{0, 0}, {10, 5}]
    end

    test "self-steal delta is difference in lengths" do
      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cat",
          letter_count: 10
        },
        %WordSteal{
          victim_team_idx: 0,
          victim_word: "cat",
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "scatter",
          letter_count: 20
        }
      ]

      state = %{
        teams: [%{id: 0, name: "team1", score: 0, words: []}],
        players: [%{name: "player1", team_id: 0, score: 0}],
        players_teams: %{0 => 0}
      }

      result = ScoreService.calculate_history_stats(state, history)
      assert result.score_timeline[0] == [{0, 0}, {10, 2}, {20, 6}]
    end

    test "cross-team steal affects both teams" do
      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "dog",
          letter_count: 10
        },
        %WordSteal{
          victim_team_idx: 0,
          victim_word: "dog",
          thief_team_idx: 1,
          thief_player_idx: 1,
          thief_word: "dogs",
          letter_count: 20
        }
      ]

      state = %{
        teams: [
          %{id: 0, name: "team1", score: 0, words: []},
          %{id: 1, name: "team2", score: 0, words: []}
        ],
        players: [
          %{name: "player1", team_id: 0, score: 0},
          %{name: "player2", team_id: 1, score: 0}
        ],
        players_teams: %{0 => 0, 1 => 1}
      }

      result = ScoreService.calculate_history_stats(state, history)
      assert result.score_timeline[0] == [{0, 0}, {10, 2}, {20, 0}]
      assert result.score_timeline[1] == [{0, 0}, {20, 3}]
    end
  end

  describe "player stats edge cases" do
    test "player with zero steals has zero points_per_steal" do
      history = []

      state = %{
        teams: [%{id: 0, name: "team1", score: 0, words: []}],
        players: [%{name: "player1", team_id: 0, score: 0}],
        players_teams: %{0 => 0}
      }

      result = ScoreService.calculate_history_stats(state, history)
      assert result.raw_player_stats[0].points_per_steal == 0
    end

    test "player with fractional points_per_steal" do
      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cat",
          letter_count: 10
        },
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "dog",
          letter_count: 20
        },
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "elephant",
          letter_count: 30
        }
      ]

      state = %{
        teams: [%{id: 0, name: "team1", score: 0, words: []}],
        players: [%{name: "player1", team_id: 0, score: 0}],
        players_teams: %{0 => 0}
      }

      result = ScoreService.calculate_history_stats(state, history)
      total_points = 2 + 2 + 7
      assert result.raw_player_stats[0].points == total_points
      assert result.raw_player_stats[0].steals == 3
      assert result.raw_player_stats[0].points_per_steal == total_points / 3
    end

    test "multiple players on same team all tracked" do
      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cat",
          letter_count: 10
        },
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 1,
          thief_word: "dog",
          letter_count: 20
        },
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 2,
          thief_word: "fox",
          letter_count: 30
        }
      ]

      state = %{
        teams: [%{id: 0, name: "team1", score: 0, words: []}],
        players: [
          %{name: "player1", team_id: 0, score: 0},
          %{name: "player2", team_id: 0, score: 0},
          %{name: "player3", team_id: 0, score: 0}
        ],
        players_teams: %{0 => 0, 1 => 0, 2 => 0}
      }

      result = ScoreService.calculate_history_stats(state, history)
      assert result.raw_player_stats[0].points == 2
      assert result.raw_player_stats[1].points == 2
      assert result.raw_player_stats[2].points == 2
      assert result.raw_player_stats[0].steals == 1
      assert result.raw_player_stats[1].steals == 1
      assert result.raw_player_stats[2].steals == 1
    end
  end

  describe "heatmap edge cases" do
    test "empty history produces empty heatmap" do
      state = %{
        teams: [%{id: 0, name: "team1", score: 0, words: []}],
        players: [%{name: "player1", team_id: 0, score: 0}],
        players_teams: %{0 => 0}
      }

      result = ScoreService.calculate_history_stats(state, [])
      assert result.heatmap == %{}
      assert result.heatmap_max == 0
    end

    test "single steal creates single heatmap entry" do
      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cat",
          letter_count: 50
        }
      ]

      state = %{
        teams: [%{id: 0, name: "team1", score: 0, words: []}],
        players: [%{name: "player1", team_id: 0, score: 0}],
        players_teams: %{0 => 0}
      }

      result = ScoreService.calculate_history_stats(state, history)
      assert result.heatmap == %{50 => 3}
      assert result.heatmap_max == 3
    end

    test "multiple steals at same letter_count accumulate" do
      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cat",
          letter_count: 50
        },
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "dog",
          letter_count: 50
        },
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "fox",
          letter_count: 50
        }
      ]

      state = %{
        teams: [%{id: 0, name: "team1", score: 0, words: []}],
        players: [%{name: "player1", team_id: 0, score: 0}],
        players_teams: %{0 => 0}
      }

      result = ScoreService.calculate_history_stats(state, history)
      assert result.heatmap == %{50 => 9}
      assert result.heatmap_max == 9
    end
  end

  describe "best_steal tracking" do
    test "first steal becomes best_steal initially" do
      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cat",
          letter_count: 10
        }
      ]

      state = %{
        teams: [%{id: 0, name: "team1", score: 0, words: []}],
        players: [%{name: "player1", team_id: 0, score: 0}],
        players_teams: %{0 => 0}
      }

      result = ScoreService.calculate_history_stats(state, history)
      assert result.best_steal.thief_word == "cat"
      assert result.best_steal_score > 0
    end

    test "best_steal updates when better steal occurs" do
      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cat",
          letter_count: 10
        },
        %WordSteal{
          victim_team_idx: 0,
          victim_word: "cat",
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "scatter",
          letter_count: 20
        }
      ]

      state = %{
        teams: [%{id: 0, name: "team1", score: 0, words: []}],
        players: [%{name: "player1", team_id: 0, score: 0}],
        players_teams: %{0 => 0}
      }

      result = ScoreService.calculate_history_stats(state, history)
      assert result.best_steal.thief_word == "scatter"
    end
  end

  describe "challenge_stats with multiple players" do
    test "tracks per-player challenge stats correctly" do
      past_challenges = [
        %{
          id: 1,
          word_steal: %{thief_word: "word1", thief_player_idx: 0},
          result: true
        },
        %{
          id: 2,
          word_steal: %{thief_word: "word2", thief_player_idx: 0},
          result: false
        },
        %{
          id: 3,
          word_steal: %{thief_word: "word3", thief_player_idx: 1},
          result: true
        },
        %{
          id: 4,
          word_steal: %{thief_word: "word4", thief_player_idx: 1},
          result: true
        }
      ]

      stats = ScoreService.calculate_challenge_stats(past_challenges)
      assert stats.count == 4
      assert stats.valid_ct == 3
      assert stats.player_stats[0] == %{count: 2, valid_ct: 1}
      assert stats.player_stats[1] == %{count: 2, valid_ct: 2}
    end

    test "only invalid challenges appear in invalid_word_steals" do
      invalid_steal = %{thief_word: "invalid", thief_player_idx: 0}
      valid_steal = %{thief_word: "valid", thief_player_idx: 1}

      past_challenges = [
        %{id: 1, word_steal: invalid_steal, result: false},
        %{id: 2, word_steal: valid_steal, result: true}
      ]

      stats = ScoreService.calculate_challenge_stats(past_challenges)
      assert length(stats.invalid_word_steals) == 1
      assert hd(stats.invalid_word_steals) == invalid_steal
    end
  end

  describe "total_score accumulation" do
    test "sums all team scores correctly" do
      state = %{
        status: :finished,
        center: [],
        center_sorted: [],
        start_time: ~U[2025-01-01 00:00:00Z],
        end_time: ~U[2025-01-01 00:10:00Z],
        past_challenges: [],
        teams: [
          %{id: 0, name: "team1", score: 15, words: []},
          %{id: 1, name: "team2", score: 23, words: []},
          %{id: 2, name: "team3", score: 7, words: []}
        ],
        players: [
          %{name: "player1", team_id: 0, score: 0},
          %{name: "player2", team_id: 1, score: 0},
          %{name: "player3", team_id: 2, score: 0}
        ],
        players_teams: %{0 => 0, 1 => 1, 2 => 2},
        history: []
      }

      state = ScoreService.calculate_game_stats(state)
      assert state.game_stats.total_score == 45
    end
  end

  describe "score_timeline_max calculation" do
    test "finds maximum score across all teams and all points in time" do
      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "elephant",
          letter_count: 10
        },
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 1,
          thief_player_idx: 1,
          thief_word: "dog",
          letter_count: 20
        }
      ]

      state = %{
        teams: [
          %{id: 0, name: "team1", score: 0, words: []},
          %{id: 1, name: "team2", score: 0, words: []}
        ],
        players: [
          %{name: "player1", team_id: 0, score: 0},
          %{name: "player2", team_id: 1, score: 0}
        ],
        players_teams: %{0 => 0, 1 => 1}
      }

      result = ScoreService.calculate_history_stats(state, history)
      assert result.score_timeline_max == 7
    end

    test "score_timeline_max is zero for empty history" do
      state = %{
        teams: [%{id: 0, name: "team1", score: 0, words: []}],
        players: [%{name: "player1", team_id: 0, score: 0}],
        players_teams: %{0 => 0}
      }

      result = ScoreService.calculate_history_stats(state, [])
      assert result.score_timeline_max == 0
    end
  end

  describe "calculate_team_scores with Team module" do
    test "delegates to Team.calculate_score for each team" do
      team1 = Team.new("Pirates", ["boat", "goats", "zoo"])
      team2 = Team.new("Vikings", ["cat", "bat"])

      state = %{teams: [team1, team2]}
      result = ScoreService.calculate_team_scores(state)

      assert result.teams |> Enum.at(0) |> Map.get(:score) == 9
      assert result.teams |> Enum.at(1) |> Map.get(:score) == 4
    end

    test "handles empty team list" do
      state = %{teams: []}
      result = ScoreService.calculate_team_scores(state)
      assert result.teams == []
    end

    test "handles teams with empty word lists" do
      team1 = Team.new("Empty1", [])
      team2 = Team.new("Empty2", [])

      state = %{teams: [team1, team2]}
      result = ScoreService.calculate_team_scores(state)

      assert result.teams |> Enum.at(0) |> Map.get(:score) == 0
      assert result.teams |> Enum.at(1) |> Map.get(:score) == 0
    end
  end

  describe "word_length_distribution with empty inputs" do
    test "empty word list returns empty distribution" do
      teams = [%{id: 0, name: "team1", score: 0, words: []}]
      stats = ScoreService.calculate_team_stats(teams)
      assert stats.word_length_distribution == %{}
    end

    test "single empty string word (edge case)" do
      teams = [%{id: 0, name: "team1", score: 0, words: [""]}]
      stats = ScoreService.calculate_team_stats(teams)
      assert stats.word_length_distribution == %{0 => 1}
    end
  end

  describe "complex game scenario" do
    test "full game with mixed steals and challenges" do
      cats_steal = %WordSteal{
        victim_team_idx: 0,
        victim_word: "cat",
        thief_team_idx: 1,
        thief_player_idx: 1,
        thief_word: "cats",
        letter_count: 50
      }

      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cat",
          letter_count: 10
        },
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 1,
          thief_player_idx: 1,
          thief_word: "dog",
          letter_count: 20
        },
        %WordSteal{
          victim_team_idx: 0,
          victim_word: "cat",
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "scatter",
          letter_count: 30
        },
        cats_steal,
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "fox",
          letter_count: 60
        }
      ]

      past_challenges = [
        %{id: 1, word_steal: cats_steal, result: false}
      ]

      state = %{
        status: :finished,
        center: [],
        center_sorted: [],
        start_time: ~U[2025-01-01 00:00:00Z],
        end_time: ~U[2025-01-01 00:15:00Z],
        past_challenges: past_challenges,
        teams: [
          %{id: 0, name: "team1", score: 10, words: ["scatter", "fox"]},
          %{id: 1, name: "team2", score: 2, words: ["dog"]}
        ],
        players: [
          %{name: "player1", team_id: 0, score: 0},
          %{name: "player2", team_id: 1, score: 0}
        ],
        players_teams: %{0 => 0, 1 => 1},
        history: history
      }

      result = ScoreService.calculate_game_stats(state)
      stats = result.game_stats

      assert stats.total_steals == 4
      assert stats.challenge_stats.count == 1
      assert stats.challenge_stats.valid_ct == 0
      assert length(stats.challenge_stats.invalid_word_steals) == 1
      assert stats.game_duration == 900

      player0_points = 2 + 4 + 2
      assert stats.raw_player_stats[0].points == player0_points
      assert stats.raw_player_stats[0].steals == 3

      assert stats.raw_player_stats[1].points == 2
      assert stats.raw_player_stats[1].steals == 1

      assert stats.raw_mvp.player_idx == 0
    end
  end

  describe "special characters and unicode in words" do
    test "handles unicode characters in words" do
      teams = [
        %{id: 0, name: "team1", score: 0, words: ["café", "naïve"]}
      ]

      stats = ScoreService.calculate_team_stats(teams)
      assert stats.word_count == 2
    end

    test "letter pairs handles unicode" do
      pairs = ScoreService.get_letter_pairs("café")
      assert length(pairs) == 3
      assert {"c", "a"} in pairs
      assert {"a", "f"} in pairs
      assert {"f", "é"} in pairs
    end
  end

  describe "mvp with tied scores" do
    test "mvp selection when multiple players tied" do
      history = [
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cat",
          letter_count: 10
        },
        %WordSteal{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 1,
          thief_player_idx: 1,
          thief_word: "dog",
          letter_count: 20
        }
      ]

      state = %{
        status: :finished,
        center: [],
        center_sorted: [],
        start_time: ~U[2025-01-01 00:00:00Z],
        end_time: ~U[2025-01-01 00:10:00Z],
        past_challenges: [],
        teams: [
          %{id: 0, name: "team1", score: 2, words: ["cat"]},
          %{id: 1, name: "team2", score: 2, words: ["dog"]}
        ],
        players: [
          %{name: "player1", team_id: 0, score: 0},
          %{name: "player2", team_id: 1, score: 0}
        ],
        players_teams: %{0 => 0, 1 => 1},
        history: history
      }

      result = ScoreService.calculate_game_stats(state)
      assert result.game_stats.raw_mvp.points == 2
      assert result.game_stats.raw_mvp.player_idx in [0, 1]
    end
  end

  describe "large numbers and stress cases" do
    test "handles many teams" do
      teams =
        for i <- 0..9 do
          %{id: i, name: "team#{i}", score: i * 5, words: []}
        end

      stats = ScoreService.calculate_team_stats(teams)
      assert stats.total_score == Enum.sum(0..9) * 5
      assert stats.word_count == 0
    end

    test "handles many players with many steals" do
      history =
        for i <- 0..99 do
          %WordSteal{
            victim_team_idx: nil,
            victim_word: nil,
            thief_team_idx: rem(i, 5),
            thief_player_idx: i,
            thief_word: "word#{i}",
            letter_count: i
          }
        end

      players =
        for i <- 0..99 do
          %{name: "player#{i}", team_id: rem(i, 5), score: 0}
        end

      teams =
        for i <- 0..4 do
          %{id: i, name: "team#{i}", score: 0, words: []}
        end

      state = %{
        teams: teams,
        players: players,
        players_teams: Map.new(0..99, fn i -> {i, rem(i, 5)} end)
      }

      result = ScoreService.calculate_history_stats(state, history)
      assert result.total_steals == 100
      assert map_size(result.raw_player_stats) == 100
      assert Enum.all?(result.raw_player_stats, fn {_, stats} -> stats.steals == 1 end)
    end

    test "handles very long words" do
      long_word = String.duplicate("a", 1000)

      teams = [%{id: 0, name: "team1", score: 999, words: [long_word]}]
      stats = ScoreService.calculate_team_stats(teams)
      assert stats.word_length_distribution == %{1000 => 1}
      assert stats.avg_word_length == 1000.0
    end
  end
end
