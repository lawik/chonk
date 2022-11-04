defmodule Chonk.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      ChonkWeb.Telemetry,
      # Chonk.Image,
      # Start the PubSub system
      {Phoenix.PubSub, name: Chonk.PubSub},
      # Start the Endpoint (http/https)
      ChonkWeb.Endpoint
      # Start a worker by calling: Chonk.Worker.start_link(arg)
      # {Chonk.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Chonk.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ChonkWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
