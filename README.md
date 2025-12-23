# Piratex

A [Pirate Scrabble](https://piratescrabble.com) implementation. See `piratescrabble.com/rules` for how to play.

## Setup

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `make`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## TODO

- [ ] UI for turn timer
- [ ] UI for challenge timer
- [ ] Add Flash message on game start or info in waiting to tell people to hit 0 to see hotkeys
- [ ] Delight when turn
- [ ] Delight when word is claimed
- [ ] Delight when challenge is resolved
- [ ] Improve waiting games list.
- [x] Make the title Pirate Scrabble animate (flip or fill in like a typewriter)
- [] Graph of score across flips (time)
- [ ] Add messages from server to client for populating flash messages to explain events. 
- [ ] Attempting to join with taken name fails back to /find. Instead, put_flash
- [ ] Error message massaging: no snake case, no atom colons, make it human readable
- [ ] I don't think CICD is actually using dependencies cache.

## Nice to Haves
- [ ] Delight when turn
- [ ] Delight when word is claimed
- [ ] Delight when challenge is resolved
- [ ] Stats page showing games in progress


### Open Questions
- How do we prevent a Player token from being copied to multiple web clients, allowing multiple people to play as a single user (an unfair advantage)? Seems like checking IP/headers could work. 

Messages: 

Page Load: 
*
ONLY on page load:
- id
- initial_letter_count

Waiting Update:
- Players
- Teams
- teams_players

Playing Update:
- status? Could just rely on the pubsub message
- NOT players
- teams (for words)
- center
- turn
- total_turn
- history
- challenges
- letter_pool (only for UI). Maybe just return length of letter pool

Finished Update:
- status
- teams (with scores)
- game statistics (NEW)


Ideas for Quality Score: 
- TileCount - 2x count(3LetterWords) - .5x count(4LetterWords) - lettersInCenter
- TileCount - sum(TeamScores)
- 1/K-(medianWordLength)

Count Neighbor differences: 
- For each letter, 1 point for each neighbor that is different. 
- for a new letter, 