defmodule Piratex.ScoreServiceTest do
  use ExUnit.Case

  alias Piratex.Team
  alias Piratex.ScoreService
  alias Piratex.WordSteal

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
                 words: ["bit", "baste", "bet"],
                 steals: 3,
                 points_per_steal: 8 / 3
               },
               1 => %{
                 points: 4,
                 words: ["sat", "set"],
                 steals: 2,
                 points_per_steal: 2
               }
             }

      assert state.game_stats.raw_mvp == %{
               player_idx: 0,
               points: 8,
               words: ["bit", "baste", "bet"],
               steals: 3,
               points_per_steal: 8 / 3
             }

      assert state.game_stats.challenge_stats == %{
               count: 0,
               valid_ct: 0,
               player_stats: %{},
               invalid_word_steals: []
             }
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
    end

    test "steal from same team" do
    end

    test "failed challenges are filtered out" do
    end

    test "word is stolen multiple times" do
    end

    test "4 players on 2 teams" do
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
