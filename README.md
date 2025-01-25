# Piratex

A word game.

## Setup

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `make`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## TODO

- [ ] Address the dark mode issue
- [ ] Fix vertical Spacing between Center letters 
- [ ] Make Flash messages go away after a few seconds
- [ ] Mobile UI 
- [ ] Fix 1-person challenges (auto-reject)
- [ ] When player word area is at max width, words will overflow. Make it scrollable

### Open Questions
- How do we prevent a Player token from being copied to multiple web clients, allowing multiple people to play as a single user (an unfair advantage)? Seems like checking IP/headers could work. 