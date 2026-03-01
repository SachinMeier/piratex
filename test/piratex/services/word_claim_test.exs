defmodule Piratex.WordClaimServiceTest do
  use ExUnit.Case, async: true

  alias Piratex.WordClaimService

  import Piratex.TestHelpers

  alias Piratex.Helpers
  alias Piratex.Player
  alias Piratex.Team
  alias Piratex.WordClaimService
  alias Piratex.ChallengeService

  setup do
    case Piratex.Dictionary.start_link(nil) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      {:error, reason} -> raise "Failed to start dictionary: #{inspect(reason)}"
    end

    :ok
  end

  test "calculate_word_product" do
    assert WordClaimService.calculate_word_product("a") == 2
    assert WordClaimService.calculate_word_product("ab") == 6
    assert WordClaimService.calculate_word_product("abc") == 30
  end

  test "add_letter_to_word_product" do
    # multiplies the current product by the prime number associated with the letter
    assert WordClaimService.add_letter_to_word_product(2, "a") == 4
    assert WordClaimService.add_letter_to_word_product(2, "b") == 6
    assert WordClaimService.add_letter_to_word_product(2, "c") == 10
  end

  describe "handle_word_claim/3" do
    # from TestHelpers
    setup :new_game_state

    # tests:
    # - SUCCESS: word is valid and can be built from center entirely
    test "take valid word entirely from center", %{
      state: state,
      players: _players,
      t1: t1,
      t2: t2,
      p1: p1
    } do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      %{words: t1_words} = t1
      %{words: t2_words} = t2

      {:ok, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert new_state.center == []
      assert team_has_word(new_state, t1.id, "eat")

      # ensure that t1 still has all their old words
      for word <- t1_words do
        assert team_has_word(new_state, t1.id, word)
      end

      # ensure that t2 still has all their words
      for word <- t2_words do
        assert team_has_word(new_state, t2.id, word)
      end
    end

    # - SUCCESS: steal from self
    test "take valid word from self", %{state: state, players: _players, t1: t1, t2: t2, p2: p2} do
      state = Helpers.add_letters_to_center(state, ["e"])
      %{words: t1_words} = t1
      %{words: t2_words} = t2

      # p2 has "bing"
      {:ok, new_state} = WordClaimService.handle_word_claim(state, t2, p2, "binge")
      assert new_state.center == []
      assert team_has_word(new_state, t2.id, "binge")

      # ensure that p1 still has all their old words
      for word <- t1_words do
        assert team_has_word(new_state, t1.id, word)
      end

      # ensure that p2 still has all their old words except the one they turned into "binge"
      for word <- t2_words -- ["bing"] do
        assert team_has_word(new_state, t2.id, word)
      end
    end

    # - SUCCESS: steal from another player
    test "steal from another player", %{
      state: state,
      players: _players,
      t1: t1,
      t2: t2,
      p1: p1,
      p2: _p2
    } do
      state = Helpers.add_letters_to_center(state, ["e"])
      %{words: t1_words} = t1
      %{words: t2_words} = t2

      # p2 has "bing"
      {:ok, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "binge")
      assert new_state.center == []
      assert team_has_word(new_state, t1.id, "binge")

      # ensure that p1 still has all their old words
      for word <- t1_words do
        assert team_has_word(new_state, t1.id, word)
      end

      # ensure that p2 still has all their old words except the one they lost to "binge"
      for word <- t2_words -- ["bing"] do
        assert team_has_word(new_state, t2.id, word)
      end
    end

    # - FAIL: word is invalid
    test "word is invalid", %{state: state, players: _players, t1: t1, p1: p1, p2: _p2} do
      {:invalid_word, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "napalmer")
      # ensure nothing has changed
      assert new_state == state
    end

    # - FAIL: word already in play
    test "word is already in play", %{state: state, players: _players, t1: t1, p1: p1, p2: _p2} do
      {:word_in_play, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "bang")
      # ensure nothing has changed
      assert new_state == state
    end

    # - FAIL: word is valid but cannot be built from center
    test "word is valid but cannot be built from center", %{
      state: state,
      players: _players,
      t1: t1,
      p1: p1,
      p2: _p2
    } do
      {:cannot_make_word, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "binged")
      # ensure nothing has changed
      assert new_state == state

      state = Helpers.add_letters_to_center(state, ["e"])
      # still no "d"
      {:cannot_make_word, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "binged")
      # ensure nothing has changed
      assert new_state == state
    end

    test "imply -> simply", %{state: state, players: _players, t1: t1, t2: t2, p1: p1, p2: p2} do
      state = Helpers.add_letters_to_center(state, ["i", "m", "p", "l", "y"])
      {:ok, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "imply")
      assert new_state.center == []
      assert team_has_word(new_state, t1.id, "imply")

      state = Helpers.add_letters_to_center(state, ["s"])

      {:ok, new_state} = WordClaimService.handle_word_claim(state, t2, p2, "simply")
      assert new_state.center == []
      assert team_has_word(new_state, t2.id, "simply")
      refute team_has_word(new_state, t1.id, "imply")
    end
  end

  # somewhat redundant with handle_word_claim/3, but useful for testing
  describe "update_state_for_word_steal" do
    setup do
      p1 = Player.new("token1", "name1")
      p2 = Player.new("token2", "name2")

      t1 = Team.new("team1", ["cop", "cap", "cup"])
      t2 = Team.new("team2", ["bot", "bat", "but"])

      state =
        default_new_game(2, %{
          players: [p1, p2],
          teams: [t1, t2],
          players_teams: %{
            p1.token => t1.id,
            p2.token => t2.id
          },
          center: ["a", "b", "c", "e"],
          center_sorted: ["a", "b", "c", "e"]
        })

      {:ok, state: state, t1: t1, t2: t2, p1: p1, p2: p2}
    end

    test "player2 steals cope from player1's cop", %{
      state: state,
      t1: t1,
      t2: t2,
      p1: _p1,
      p2: p2
    } do
      new_state =
        WordClaimService.update_state_for_word_steal(
          state,
          %{
            letters_used: ["e"],
            thief_team: t2,
            thief_player: p2,
            new_word: "cope",
            victim_team: t1,
            old_word: "cop"
          }
        )

      assert new_state.center == ["a", "b", "c"]

      assert [
               %{words: ["cap", "cup"]},
               %{words: ["cope", "bot", "bat", "but"]}
             ] = new_state.teams
    end

    test "player1 steals cope from his own cop", %{
      state: state,
      t1: t1,
      t2: _t2,
      p1: p1,
      p2: _p2
    } do
      new_state =
        WordClaimService.update_state_for_word_steal(
          state,
          %{
            letters_used: ["e"],
            thief_team: t1,
            thief_player: p1,
            new_word: "cope",
            victim_team: t1,
            old_word: "cop"
          }
        )

      assert new_state.center == ["a", "b", "c"]

      assert [
               %{words: ["cope", "cap", "cup"]},
               %{words: ["bot", "bat", "but"]}
             ] = new_state.teams
    end

    test "player1 steals cab from center", %{state: state, t1: t1, t2: _t2, p1: p1, p2: _p2} do
      new_state =
        WordClaimService.update_state_for_word_steal(
          state,
          %{
            letters_used: ["c", "a", "b"],
            thief_team: t1,
            thief_player: p1,
            new_word: "cab",
            victim_team: nil,
            old_word: nil
          }
        )

      assert new_state.center == ["e"]

      assert [
               %{words: ["cab", "cop", "cap", "cup"]},
               %{words: ["bot", "bat", "but"]}
             ] = new_state.teams
    end
  end

  describe "is_recidivist_word_claim?" do
    # from TestHelpers
    setup :new_game_state

    test "returns true if the word has been previously challenged and rejected (victimless)", %{
      state: state,
      t1: t1,
      t2: t2,
      p1: %{token: p1_token} = p1,
      p2: %{token: p2_token} = p2
    } do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert state.center == []
      assert team_has_word(state, t1.id, "eat")

      # the word is not yet recidivist
      refute WordClaimService.is_recidivist_word_claim?(state, "eat", nil)

      # challenge the word
      state = ChallengeService.handle_word_challenge(state, p2_token, "eat")
      challenge_id = Enum.at(state.challenges, 0).id

      # while the challenge is open, the word is not yet recidivist
      refute WordClaimService.is_recidivist_word_claim?(state, "eat", nil)

      # p1 concurs, word is invalid
      assert state =
               ChallengeService.handle_challenge_vote(state, p1_token, challenge_id, false)

      refute team_has_word(state, t1.id, "eat")
      assert match_center?(state, ["e", "a", "t"])

      # from now on, <nil> -> "eat" is recidivist
      assert WordClaimService.is_recidivist_word_claim?(state, "eat", nil)

      # try to claim eat again
      {:invalid_word, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      {:invalid_word, _state} = WordClaimService.handle_word_claim(state, t2, p2, "eat")
    end

    test "returns true if the word has been previously challenged and rejected (victim word)", %{
      state: state,
      t1: t1,
      t2: t2,
      p1: %{token: p1_token} = p1,
      p2: %{token: p2_token} = p2
    } do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert state.center == []
      assert team_has_word(state, t1.id, "eat")

      state = Helpers.add_letters_to_center(state, ["s"])
      {:ok, state} = WordClaimService.handle_word_claim(state, t2, p2, "eats")
      assert team_has_word(state, t2.id, "eats")
      refute team_has_word(state, t1.id, "eat")

      # not yet recidivist
      refute WordClaimService.is_recidivist_word_claim?(state, "eat", "eats")

      # challenge eat->eats
      state = ChallengeService.handle_word_challenge(state, p1_token, "eats")
      challenge_id = Enum.at(state.challenges, 0).id
      # p2 concurs, word is invalid
      assert state =
               ChallengeService.handle_challenge_vote(state, p2_token, challenge_id, false)

      assert team_has_word(state, t1.id, "eat")
      refute team_has_word(state, t2.id, "eats")

      # from now on, "eat" -> "eats" is recidivist
      assert WordClaimService.is_recidivist_word_claim?(state, "eats", "eat")

      {:invalid_word, state} = WordClaimService.handle_word_claim(state, t1, p1, "eats")
      {:invalid_word, state} = WordClaimService.handle_word_claim(state, t2, p2, "eats")

      assert team_has_word(state, t1.id, "eat")
      refute team_has_word(state, t2.id, "eats")
      assert match_center?(state, ["s"])
    end

    test "returns false if the word has not been previously challenged", %{
      state: state,
      t1: t1,
      p1: p1
    } do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      refute WordClaimService.is_recidivist_word_claim?(state, "eat", nil)

      {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert state.center == []
      assert team_has_word(state, t1.id, "eat")

      refute WordClaimService.is_recidivist_word_claim?(state, "eat", nil)
    end

    test "returns false if the word has been previously challenged and accepted", %{
      state: state,
      t1: t1,
      t2: t2,
      p1: %{token: p1_token} = p1,
      p2: %{token: p2_token} = p2
    } do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert state.center == []
      assert team_has_word(state, t1.id, "eat")

      # the word is not yet recidivist
      refute WordClaimService.is_recidivist_word_claim?(state, "eat", nil)

      # challenge the word
      state = ChallengeService.handle_word_challenge(state, p2_token, "eat")
      challenge_id = Enum.at(state.challenges, 0).id

      # while the challenge is open, the word is not yet recidivist
      refute WordClaimService.is_recidivist_word_claim?(state, "eat", nil)

      # p1 disagrees, word is valid
      assert state =
               ChallengeService.handle_challenge_vote(state, p1_token, challenge_id, true)

      refute WordClaimService.is_recidivist_word_claim?(state, "eat", nil)

      state = Helpers.add_letters_to_center(state, ["s"])
      {:ok, state} = WordClaimService.handle_word_claim(state, t2, p2, "east")
      assert team_has_word(state, t2.id, "east")
      refute team_has_word(state, t1.id, "eat")

      refute WordClaimService.is_recidivist_word_claim?(state, "east", "eat")

      # challenge east->eat
      state = ChallengeService.handle_word_challenge(state, p1_token, "east")
      challenge_id = Enum.at(state.challenges, 0).id

      # p2 disagrees, word is valid
      assert state =
               ChallengeService.handle_challenge_vote(state, p2_token, challenge_id, true)

      refute WordClaimService.is_recidivist_word_claim?(state, "east", "eat")
    end
  end

  describe "handle_word_claim - min word length" do
    setup :new_game_state

    test "rejects a single-letter word", %{state: state, t1: t1, p1: p1} do
      state = Helpers.add_letters_to_center(state, ["a"])
      {:invalid_word, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "a")
      assert new_state == state
    end

    test "rejects a two-letter word", %{state: state, t1: t1, p1: p1} do
      state = Helpers.add_letters_to_center(state, ["a", "t"])
      {:invalid_word, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "at")
      assert new_state == state
    end

    test "rejects an empty string", %{state: state, t1: t1, p1: p1} do
      {:invalid_word, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "")
      assert new_state == state
    end
  end

  describe "handle_word_claim - word not in dictionary" do
    setup :new_game_state

    test "rejects complete gibberish", %{state: state, t1: t1, p1: p1} do
      state = Helpers.add_letters_to_center(state, ["x", "z", "q"])
      {:invalid_word, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "xzq")
      assert new_state == state
    end

    test "rejects an almost-valid word (misspelling)", %{state: state, t1: t1, p1: p1} do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t", "z"])
      {:invalid_word, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "eatz")
      assert new_state == state
    end

    test "rejects a long nonsense word", %{state: state, t1: t1, p1: p1} do
      state = Helpers.add_letters_to_center(state, ["f", "l", "u", "r", "b", "o", "x"])
      {:invalid_word, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "flurbox")
      assert new_state == state
    end

    test "rejects a word that is a valid prefix but not a word itself", %{
      state: state,
      t1: t1,
      p1: p1
    } do
      state = Helpers.add_letters_to_center(state, ["u", "n", "d"])
      {:invalid_word, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "und")
      assert new_state == state
    end
  end

  describe "calculate_word_product/1 - list input" do
    test "calculates product from a list of single letters" do
      assert WordClaimService.calculate_word_product(["a"]) == 2
      assert WordClaimService.calculate_word_product(["a", "b"]) == 6
      assert WordClaimService.calculate_word_product(["a", "b", "c"]) == 30
    end

    test "list input matches string input for the same word" do
      string_product = WordClaimService.calculate_word_product("hello")
      list_product = WordClaimService.calculate_word_product(["h", "e", "l", "l", "o"])
      assert string_product == list_product
    end

    test "order of letters does not matter (anagram detection)" do
      product_eat = WordClaimService.calculate_word_product(["e", "a", "t"])
      product_tea = WordClaimService.calculate_word_product(["t", "e", "a"])
      product_ate = WordClaimService.calculate_word_product(["a", "t", "e"])
      assert product_eat == product_tea
      assert product_tea == product_ate
    end

    test "different letters produce different products" do
      product_abc = WordClaimService.calculate_word_product(["a", "b", "c"])
      product_def = WordClaimService.calculate_word_product(["d", "e", "f"])
      refute product_abc == product_def
    end

    test "single letter list" do
      assert WordClaimService.calculate_word_product(["z"]) == 101
    end
  end

  describe "handle_word_claim - duplicate word in play" do
    setup :new_game_state

    test "rejects a word that exists on the claimant's own team", %{state: state, t1: t1, p1: p1} do
      # t1 already has "bind", "band", "bond"
      {:word_in_play, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "bind")
      assert new_state == state
    end

    test "rejects a word that exists on another team", %{state: state, t1: t1, p1: p1} do
      # t2 already has "bing", "bang", "bong"
      {:word_in_play, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "bing")
      assert new_state == state
    end

    test "rejects a word that was just claimed from center", %{
      state: state,
      t1: t1,
      t2: t2,
      p1: p1,
      p2: p2
    } do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert team_has_word(state, t1.id, "eat")

      # p2 tries to also claim "eat" which is now on t1
      {:word_in_play, new_state} = WordClaimService.handle_word_claim(state, t2, p2, "eat")
      assert new_state == state
    end
  end

  describe "handle_word_claim - stealing from multiple teams" do
    setup do
      p1 = Player.new("name1", "token1")
      p2 = Player.new("name2", "token2")
      p3 = Player.new("name3", "token3")

      t1 = Team.new("team1", ["cat", "dog"])
      t2 = Team.new("team2", ["bat", "log"])
      t3 = Team.new("team3", ["rat", "fog"])

      {letter_count, letter_pool} = Piratex.LetterPoolService.load_letter_pool(:bananagrams)

      state = %{
        id: "MULTI",
        status: :playing,
        players: [p1, p2, p3],
        players_teams: %{
          p1.token => t1.id,
          p2.token => t2.id,
          p3.token => t3.id
        },
        teams: [t1, t2, t3],
        turn: 0,
        total_turn: 0,
        letter_pool: letter_pool,
        initial_letter_count: letter_count,
        center: [],
        center_sorted: [],
        history: [],
        challenges: [],
        past_challenges: [],
        end_game_votes: %{},
        last_action_at: DateTime.utc_now()
      }

      {:ok, state: state, t1: t1, t2: t2, t3: t3, p1: p1, p2: p2, p3: p3}
    end

    test "steals from first matching team when multiple teams have stealable words", %{
      state: state,
      t1: t1,
      t2: _t2,
      t3: t3,
      p3: p3
    } do
      state = Helpers.add_letters_to_center(state, ["s"])
      # both t1 and t2 have words that could be stolen (cat->cats, bat->bats)
      # but the code should steal from the first team it finds (t1)
      {:ok, new_state} = WordClaimService.handle_word_claim(state, t3, p3, "cats")

      assert team_has_word(new_state, t3.id, "cats")
      refute team_has_word(new_state, t1.id, "cat")
      assert team_has_word(new_state, t1.id, "dog")
      assert new_state.center == []
    end

    test "skips teams without stealable words and finds valid steal", %{
      state: state,
      t1: t1,
      t2: t2,
      t3: t3,
      p3: p3
    } do
      # Update teams to have words from test dictionary
      state = %{
        state
        | teams: [
            %{t1 | words: ["cat"]},
            %{t2 | words: ["band"]},
            %{t3 | words: []}
          ]
      }

      state = Helpers.add_letters_to_center(state, ["s"])
      # t1 has "cat", t2 has "band"
      # we want to steal "bands" from "band", so should skip t1 and find t2
      {:ok, new_state} = WordClaimService.handle_word_claim(state, t3, p3, "bands")

      assert team_has_word(new_state, t3.id, "bands")
      refute team_has_word(new_state, t2.id, "band")
      assert team_has_word(new_state, t1.id, "cat")
      assert new_state.center == []
    end
  end

  describe "handle_word_claim - anagram attempts" do
    setup :new_game_state

    test "rejects exact anagram steal (no new letters)", %{state: state, t1: t1, p1: p1} do
      # Add a word to t1 first
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert team_has_word(state, t1.id, "eat")

      # Now try to claim "ate" which is an anagram of "eat" (no new letters added)
      # This should fail with :invalid_word because no letters are added
      state = Helpers.add_letters_to_center(state, [])
      {:invalid_word, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "ate")
      assert team_has_word(new_state, t1.id, "eat")
      refute team_has_word(new_state, t1.id, "ate")
    end
  end

  describe "center letter finding edge cases" do
    setup :new_game_state

    test "finds letters when target requires skipping irrelevant letters", %{
      state: state,
      t1: t1,
      p1: p1
    } do
      # center has extra letters that aren't needed
      state = Helpers.add_letters_to_center(state, ["a", "e", "t", "x", "y", "z"])

      {:ok, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")

      assert team_has_word(new_state, t1.id, "eat")
      # should have removed only "a", "e", "t" and left "x", "y", "z"
      assert match_center?(new_state, ["x", "y", "z"])
    end

    test "early exits when letter product exceeds target", %{
      state: state,
      t1: t1,
      p1: p1
    } do
      # center_sorted is sorted alphabetically, so if we need small letters
      # and encounter a large letter, we should exit early
      # Using center with letters that can't form the word
      state = Helpers.add_letters_to_center(state, ["a", "z", "y"])

      # "ace" needs a, c, e but we only have a, z, y
      # after using "a", we need c and e (product 5*11=55)
      # but "y" has product 97 and "z" has product 101, both > 55, so should exit early
      {:cannot_make_word, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "ace")
      assert new_state == state
    end

    test "handles duplicate letters in center correctly", %{
      state: state,
      t1: t1,
      p1: p1
    } do
      # "beat" needs b, e, a, t
      state = Helpers.add_letters_to_center(state, ["b", "e", "e", "a", "t"])

      {:ok, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "beat")

      assert team_has_word(new_state, t1.id, "beat")
      # should have one "e" left
      assert match_center?(new_state, ["e"])
    end

    test "uses all center letters when building word", %{
      state: state,
      t1: t1,
      p1: p1
    } do
      state = Helpers.add_letters_to_center(state, ["c", "a", "t"])

      {:ok, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "cat")

      assert team_has_word(new_state, t1.id, "cat")
      assert new_state.center == []
      assert new_state.center_sorted == []
    end
  end

  describe "word steal history tracking" do
    setup :new_game_state

    test "adds word steal to history when stealing from center", %{
      state: state,
      t1: t1,
      p1: p1
    } do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      assert state.history == []

      {:ok, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")

      assert length(new_state.history) == 1
      [word_steal] = new_state.history

      assert word_steal.thief_word == "eat"
      assert word_steal.victim_word == nil
      assert word_steal.victim_team_idx == nil
      assert is_integer(word_steal.thief_team_idx)
      assert is_integer(word_steal.thief_player_idx)
      assert is_integer(word_steal.letter_count)
    end

    test "adds word steal to history when stealing from another player", %{
      state: state,
      t1: t1,
      t2: _t2,
      p1: p1
    } do
      state = Helpers.add_letters_to_center(state, ["e"])
      assert state.history == []

      # p1 steals "binge" from p2's "bing"
      {:ok, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "binge")

      assert length(new_state.history) == 1
      [word_steal] = new_state.history

      assert word_steal.thief_word == "binge"
      assert word_steal.victim_word == "bing"
      assert is_integer(word_steal.victim_team_idx)
      assert is_integer(word_steal.thief_team_idx)
      assert is_integer(word_steal.thief_player_idx)
    end

    test "preserves existing history when adding new word steal", %{
      state: state,
      t1: t1,
      p1: p1
    } do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t", "s"])

      {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert length(state.history) == 1

      {:ok, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "eats")
      assert length(new_state.history) == 2

      [second_steal, first_steal] = new_state.history
      assert first_steal.thief_word == "eat"
      assert second_steal.thief_word == "eats"
    end
  end

  describe "calculate_word_product - case handling" do
    test "handles uppercase letters by converting to lowercase" do
      assert WordClaimService.calculate_word_product("ABC") ==
               WordClaimService.calculate_word_product("abc")

      assert WordClaimService.calculate_word_product("HeLLo") ==
               WordClaimService.calculate_word_product("hello")
    end

    test "handles mixed case input" do
      product = WordClaimService.calculate_word_product("TeSt")
      assert is_integer(product)
      assert product > 0
    end
  end

  describe "error path preservation" do
    setup :new_game_state

    test "preserves :invalid_word error over :cannot_make_word when checking multiple words", %{
      state: state,
      t1: t1,
      t2: t2,
      p1: p1
    } do
      # Set up state where t1 has "cat" and t2 has "bat"
      state = %{
        state
        | teams: [
            %{t1 | words: ["cat"]},
            %{t2 | words: ["bat"]}
          ]
      }

      state = Helpers.add_letters_to_center(state, ["s"])

      # Try to claim "ate" which is an anagram of "eat" (if eat was in play)
      # Actually, we want to test the error bubbling. Let's use "cast" stealing from "cat"
      # but we'll mark it as recidivist first, then try to claim it
      # Add "cast" to past_challenges as rejected
      state = %{
        state
        | past_challenges: [
            %{
              word_steal: %{thief_word: "cast", victim_word: "cat"},
              result: false
            }
          ]
      }

      # Now try to claim "cast" from "cat" again
      # Team 1 has "cat" which would give :invalid_word (recidivist)
      # Team 2 has "bat" which can't make "cast", giving :cannot_make_word
      # We should get :invalid_word not :cannot_make_word
      {:invalid_word, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "cast")
      assert new_state == state
    end
  end

  describe "is_recidivist_word_claim - edge cases" do
    setup :new_game_state

    test "returns false when past_challenges is empty", %{state: state} do
      refute WordClaimService.is_recidivist_word_claim?(state, "test", nil)
      refute WordClaimService.is_recidivist_word_claim?(state, "test", "word")
    end

    test "distinguishes between victim words correctly", %{
      state: state,
      t1: t1,
      t2: t2,
      p1: %{token: p1_token} = p1,
      p2: %{token: p2_token} = p2
    } do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")

      state = Helpers.add_letters_to_center(state, ["s"])
      {:ok, state} = WordClaimService.handle_word_claim(state, t2, p2, "eats")

      # Challenge and reject "eat" -> "eats"
      state = ChallengeService.handle_word_challenge(state, p1_token, "eats")
      challenge_id = Enum.at(state.challenges, 0).id
      state = ChallengeService.handle_challenge_vote(state, p2_token, challenge_id, false)

      # Now "eat" -> "eats" is recidivist
      assert WordClaimService.is_recidivist_word_claim?(state, "eats", "eat")

      # But nil -> "eats" is NOT recidivist (different victim word)
      refute WordClaimService.is_recidivist_word_claim?(state, "eats", nil)

      # And "eats" -> "eat" is NOT recidivist (different thief word)
      refute WordClaimService.is_recidivist_word_claim?(state, "eat", "eats")
    end

    test "handles multiple failed challenges for different word pairs", %{
      state: state,
      t1: t1,
      t2: t2,
      p1: %{token: p1_token} = p1,
      p2: %{token: p2_token} = p2
    } do
      # First word claim and challenge
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")

      state = ChallengeService.handle_word_challenge(state, p2_token, "eat")
      challenge_id = Enum.at(state.challenges, 0).id
      state = ChallengeService.handle_challenge_vote(state, p1_token, challenge_id, false)

      # Second word claim and challenge
      state = Helpers.add_letters_to_center(state, ["a", "t", "e", "s"])
      {:ok, state} = WordClaimService.handle_word_claim(state, t2, p2, "eats")

      state = ChallengeService.handle_word_challenge(state, p1_token, "eats")
      challenge_id = Enum.at(state.challenges, 0).id
      state = ChallengeService.handle_challenge_vote(state, p2_token, challenge_id, false)

      # Both should be recidivist now
      assert WordClaimService.is_recidivist_word_claim?(state, "eat", nil)
      assert WordClaimService.is_recidivist_word_claim?(state, "eats", nil)

      # Try to claim them again
      state = Helpers.add_letters_to_center(state, ["e", "a", "t", "s"])
      {:invalid_word, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      {:invalid_word, _state} = WordClaimService.handle_word_claim(state, t2, p2, "eats")
    end
  end

  describe "remove_letters_from_center" do
    setup :new_game_state

    test "removes letters in correct order preserving sorted state", %{
      state: state,
      t1: t1,
      p1: p1
    } do
      state = Helpers.add_letters_to_center(state, ["t", "e", "s", "a"])
      # center is insertion order: ["t", "e", "s", "a"]
      # center_sorted is alphabetical: ["a", "e", "s", "t"]

      {:ok, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "sat")

      # Verify center_sorted is still sorted after removal
      assert new_state.center_sorted == Enum.sort(new_state.center)
      assert match_center?(new_state, ["e"])
    end

    test "handles removing duplicate letters", %{
      state: state,
      t1: t1,
      p1: p1
    } do
      # "tests" needs t, e, s, t, s (two t's and two s's)
      state = Helpers.add_letters_to_center(state, ["t", "e", "s", "t", "s", "x"])

      {:ok, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "tests")

      assert team_has_word(new_state, t1.id, "tests")
      assert match_center?(new_state, ["x"])
    end

    test "removes all letters when word uses entire center", %{
      state: state,
      t1: t1,
      p1: p1
    } do
      state = Helpers.add_letters_to_center(state, ["c", "a", "t"])

      {:ok, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "cat")

      assert new_state.center == []
      assert new_state.center_sorted == []
    end
  end

  describe "update_state_for_word_steal - comprehensive" do
    setup :new_game_state

    test "correctly updates all state fields when stealing from another team", %{
      state: state,
      t1: t1,
      t2: t2,
      p1: p1
    } do
      state = Helpers.add_letters_to_center(state, ["e"])
      initial_history_length = length(state.history)

      {:ok, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "binge")

      # Verify word was removed from victim
      refute team_has_word(new_state, t2.id, "bing")
      # Verify word was added to thief
      assert team_has_word(new_state, t1.id, "binge")
      # Verify letters removed from center
      assert new_state.center == []
      # Verify history was updated
      assert length(new_state.history) == initial_history_length + 1
    end

    test "handles stealing from own team correctly", %{
      state: state,
      t1: t1,
      p1: p1
    } do
      state = Helpers.add_letters_to_center(state, ["s"])

      {:ok, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "bands")

      # "band" should be removed
      refute team_has_word(new_state, t1.id, "band")
      # "bands" should be added
      assert team_has_word(new_state, t1.id, "bands")
      # other words should remain
      assert team_has_word(new_state, t1.id, "bind")
      assert team_has_word(new_state, t1.id, "bond")
    end
  end
end
