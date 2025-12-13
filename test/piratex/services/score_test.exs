defmodule Piratex.ScoreServiceTest do
  use ExUnit.Case

  alias Piratex.Team
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
      {51, ["potteries", "advancer", "analogue", "plowing", "renown",
            "juicy", "golfs", "need", "joey", "axe", "him"]},
      {62, ["flittering", "tolerates", "dousers", "thanked", "biome",
            "brims", "quark", "vapid", "quiz", "cave", "iota", "afar",
            "doth", "web"
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
        thief_player_idx: 0,
      } = state.game_stats.best_steal
      assert state.game_stats.raw_player_stats == %{
        0 => %{
          points: 8,
          words: ["bit", "baste", "bet"],
          steals: 3,
          points_per_steal: 8/3
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
        points_per_steal: 8/3
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
        players_teams: %{0 => 0, 1 => 1},
      }

      %{heatmap: heatmap, heatmap_max: heatmap_max} = ScoreService.calculate_history_stats(state, history)

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
              result: false,
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
              result: true,
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
              result: false,
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
              result: true,
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
  end
end
