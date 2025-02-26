# Piratex

A word game.

## Setup

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `make`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## TODO

With Samuel:
- [ ] Autoflip button
- [ ] Make letters bigger
- [ ] Fix podium UI
- [ ] UI for turn timer
- [ ] UI for challenge timer
- [ ] Delight when turn
- [ ] Delight when word is claimed
- [ ] Delight when challenge is resolved

- [ ] Check out these dictionaries: https://github.com/grubbcc/anagrams/tree/main/AnagramsServer/resources/wordlists
- [ ] BUG: navigating to /rules etc. wipes session
- [ ] Hotkeys? 
  - 1 for challenge first word
  - 2 for challenge second word
  - 3 for challenge third word
  - 5 for list of hotkeys
  - 6 for autoflip toggle
  - SPACE for flip
- [ ] merriam webster link
- [ ] Bug with 5 player challenge
- [ ] Make constants configurable
- [ ] Address the dark mode issue
- [ ] Add messages from server to client for populating flash messages to explain events. 
- [ ] Attempting to join with taken name fails back to /find. Instead, put_flash
- [ ] Setup CICD for testing and deployment (push to gigalixir)
- [ ] Error message massaging: no snake case, no atom colons, make it human readable
- [ ] Once a game has started, don't show the same join page to newcomers.
- [ ] Only show a join page for games that exist and are joinable. otherwise 404 or redirect to /find
- [ ] Private games?
- [x] Turn timer
- [x] Timeout on challenge votes
- [x] Add Game Timeout. turn timeout shouldn't keep game alive indefinitely.
- [x] Mobile UI (player action area)
- [x] Turn timer
- [x] Timeout on challenge votes
- [x] Fix vertical Spacing between Center letters 
- [x] Make Flash messages go away after a few seconds
- [x] Fix 1-person challenges (auto-reject)
- [x] When player word area is at max width, words will overflow. Make it scrollable
- [x] Progress bar for game left?
- [x] Min word length
- [x] Player count in waiting games
- [x] Challenge Button Copy (Invalid/Valid) 
- [x] Change turn if player whose turn it is leaves the game

## Nice to Haves
- [ ] Delight when turn
- [ ] Delight when word is claimed
- [ ] Delight when challenge is resolved
- [x] Change Page HTML title to "Your Turn" when it is your turn
- [ ] Stats page showing games in progress


### Open Questions
- How do we prevent a Player token from being copied to multiple web clients, allowing multiple people to play as a single user (an unfair advantage)? Seems like checking IP/headers could work. 