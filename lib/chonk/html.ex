defmodule Chonk.Html do
  use GenServer
  require Logger

  @keepalive_interval 1000
  @keepalive_update_seconds 5

  def start_link(config, opts \\ []) do
    GenServer.start_link(__MODULE__, config, opts)
  end

  def connect(conn, opts) do
    initial = opts[:initial]
    plug_pid = self()
    {:ok, pid} = Chonk.Html.start_link(%{conn: conn, plug: plug_pid, initial: initial})

    %{
      error_callback: fn ->
        Logger.info("Error callback from Plug: #{self()}")
        GenServer.cast(pid, :disconnect)
      end
    }
  end

  def update(html) do
    Phoenix.PubSub.broadcast!(Chonk.PubSub, "form-updates", {:update, html})
  end

  def render(template, assigns) do
    Phoenix.View.render_to_string(ChonkWeb.PageView, template, assigns)
  end

  @impl GenServer
  def init(config) do
    # For some reason, need to send two frames to actually get an instant result
    padding = for _ <- 1..1024, into: <<>>, do: " "
    Process.send_after(self(), {:update, "<html><head></head><body>" <> padding}, 1)
    Process.send_after(self(), {:update, :initial}, 1)
    Phoenix.PubSub.subscribe(Chonk.PubSub, "form-updates")
    keep_alive()

    {:ok,
     %{
       conn: config.conn,
       plug: config.plug,
       keepalive_content: "<!-- ping -->",
       last_update: nil,
       initial: config.initial
     }}
  end

  @impl GenServer
  def handle_cast(:disconnect, _state) do
    Logger.info("Disconnect #{self()}")
    {:stop, :normal, nil}
  end

  @impl GenServer
  def handle_info(:keepalive, %{last_update: last_update} = state) do
    diff = DateTime.diff(DateTime.now!("Etc/UTC"), last_update)
    # Logger.info("keepalive check: #{diff}")

    if diff >= @keepalive_update_seconds do
      # Logger.info("keepalive updating")
      Process.send(self(), {:update, :keepalive}, [:nosuspend])
    end

    keep_alive()

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:update, html}, state) do
    html =
      case html do
        :initial ->
          if state[:initial] do
            state[:initial]
          else
            render("index.html", %{})
          end

        :keepalive ->
          state.keepalive_content

        html ->
          html
      end

    send_frame(state.plug, html)

    {:noreply, %{state | last_update: DateTime.now!("Etc/UTC")}}
  end

  def wait_callback(_context) do
    receive do
      {:frame, frame} ->
        IO.inspect(frame, label: "frame")
        Logger.info("Received at #{inspect(self())}")
        {"text/html", frame}
    end
  end

  defp keep_alive do
    Process.send_after(self(), :keepalive, @keepalive_interval)
  end

  defp send_frame(pid, last_frame) do
    Process.send(pid, {:frame, last_frame}, [:nosuspend])
  end
end
