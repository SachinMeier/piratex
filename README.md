# Piratex

A [Pirate Scrabble](https://piratescrabble.com) implementation. See `piratescrabble.com/rules` for how to play.

## Setup

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `make`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## TODO

With Samuel:
- [x] Make letters bigger
- [ ] Fix podium UI. Should be screenshottable. only show top 3? 
- [ ] UI for turn timer
- [ ] UI for challenge timer
- [ ] Delight when turn
- [ ] Delight when word is claimed
- [ ] Delight when challenge is resolved
- [ ] Improve waiting games list.
- [ ] Make the title Pirate Scrabble animate (flip or fill in like a typewriter)

- [ ] BUG: navigating to /rules etc. wipes session
- [ ] Hotkeys? 
  - 1 for challenge first word
  - 2 for challenge second word
  - 3 for challenge third word
  - 5 for list of hotkeys
  - 6 for autoflip toggle
  - up/down for challenge voting
- [ ] Allow configurable Dictionary choice (small one for testing, different ones for different games)
- [ ] Bug with 5 player challenge
- [ ] Make constants configurable
- [ ] Only first player can start game? idk
- [ ] Address the dark mode issue
- [ ] Add messages from server to client for populating flash messages to explain events. 
- [ ] Attempting to join with taken name fails back to /find. Instead, put_flash
- [x] Setup CICD for testing and deployment (push to gigalixir)
- [ ] Error message massaging: no snake case, no atom colons, make it human readable
- [ ] Once a game has started, don't show the same join page to newcomers.
- [ ] Only show a join page for games that exist and are joinable. otherwise 404 or redirect to /find
- [ ] Private games?
- [ ] I don't think CICD is actually using dependencies cache.

## Nice to Haves
- [ ] Delight when turn
- [ ] Delight when word is claimed
- [ ] Delight when challenge is resolved
- [ ] Stats page showing games in progress


### Open Questions
- How do we prevent a Player token from being copied to multiple web clients, allowing multiple people to play as a single user (an unfair advantage)? Seems like checking IP/headers could work. 