defmodule PiratexWeb.Router do
  use PiratexWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PiratexWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # pipeline :api do
  #   plug :accepts, ["json"]
  # end

  scope "/", PiratexWeb do
    pipe_through :browser

    # home page
    live "/", Live.HomeLive, :index

    # join/rejoin a game
    live "/find", Live.FindLive, :index

    # start a new game
    get "/game/new", GameController, :new_game

    # clear the session and optionally join a new game
    get "/clear", GameController, :clear

    # choose a username and join a specific game
    live "/game/:id/join", Live.JoinGameLive, :index
    # hit this endpoint to actually join a game
    get "/game/:id/join_game", GameController, :join_game

    # game
    live_session :game, on_mount: [{PiratexWeb.GameSession, :new}] do
      live "/game/:id", Live.GameLive, :index
    end

    live "/rules", Live.RulesLive, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", PiratexWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:piratex, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PiratexWeb.Telemetry
    end
  end
end
