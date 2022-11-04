defmodule ChonkWeb.Router do
  use ChonkWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {ChonkWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :live_jpeg do
    plug Mjpeg,
      connect_callback: &Chonk.Image.connect/2,
      wait_callback: &Chonk.Image.wait_callback/1
  end

  pipeline :live_html do
    plug Chonk.Chunker,
      connect_callback: &Chonk.Html.connect/2,
      wait_callback: &Chonk.Html.wait_callback/1
  end

  scope "/", ChonkWeb do
    pipe_through :live_html

    get "/", PageController, :index
  end

  scope "/live", ChonkWeb do
    pipe_through :live_jpeg
    get "/image.jpg", PageController, :index
  end

  scope "/forms", ChonkWeb do
    post "/live", PageController, :post
    get "/live", PageController, :get
  end

  # Other scopes may use custom stacks.
  # scope "/api", ChonkWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ChonkWeb.Telemetry
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
