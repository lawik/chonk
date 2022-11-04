defmodule Chonk.Image do
  use GenServer
  import Mogrify
  require Logger

  @keepalive_interval 1000
  @keepalive_update_seconds 5

  def start_link(config, opts \\ []) do
    GenServer.start_link(__MODULE__, config, opts)
  end

  @impl GenServer
  def init(state) do
    # For some reason, need to send two frames to actually get an instant result
    Process.send_after(self(), :update, 1)
    Process.send_after(self(), :update, 2)
    Phoenix.PubSub.subscribe(Chonk.PubSub, "button-status")
    keep_alive()
    {:ok, {nil, nil, state}}
  end

  def connect(conn, _opts) do
    plug_pid = self()
    {:ok, pid} = Chonk.Image.start_link(%{conn: conn, plug: plug_pid})
    IO.inspect(conn, label: "connect")

    %{
      error_callback: fn ->
        Logger.info("Error callback from Plug: #{self()}")
        GenServer.cast(pid, :disconnect)
      end
    }
  end

  @impl GenServer
  def handle_cast(:disconnect, {_last_frame, _last_update, _config}) do
    Logger.info("Disconnect #{self()}")
    {:stop, :normal, nil}
  end

  @impl GenServer
  def handle_info(:keepalive, {_, last_update, _} = state) do
    diff = DateTime.diff(DateTime.now!("Etc/UTC"), last_update)
    # Logger.info("keepalive check: #{diff}")

    if diff >= @keepalive_update_seconds do
      # Logger.info("keepalive updating")
      Process.send(self(), :update, [:nosuspend])
    end

    keep_alive()

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:update_conn, params}, {last_frame, last_update, state}) do
    conn = state.conn
    conn = %{conn | query_params: Map.merge(conn.query_params, params)}
    state = %{state | conn: conn}
    triple = handle_info(:update, {last_frame, last_update, state})
    {:noreply, triple}
  end

  @impl GenServer
  def handle_info(:update, {_last_frame, _last_update, config}) do
    # Logger.info("Updating...")
    frame = create_frame(config.conn)
    send_frame(config.plug, frame)

    {:noreply, {frame, DateTime.now!("Etc/UTC"), config}}
  end

  def wait_callback(_context) do
    receive do
      {:frame, frame} ->
        Logger.info("Received at #{inspect(self())}")
        frame
    end
  end

  defp keep_alive do
    Process.send_after(self(), :keepalive, @keepalive_interval)
  end

  defp create_frame(conn) do
    IO.inspect(conn, label: "conn")

    template = Phoenix.View.render_to_string(ChonkWeb.UiView, "button.html", conn.query_params)

    %Mogrify.Image{path: "frame.jpg", ext: "jpg"}
    |> quality(100)
    |> custom("background", "#ffffff")
    |> custom("gravity", "center")
    |> custom("fill", "white")
    |> custom("font", "DejaVu-Sans-Mono-Bold")
    |> custom(
      "pango",
      template
    )
    |> create(path: ".")

    File.read!("frame.jpg")
  end

  defp send_frame(pid, last_frame) do
    Process.send(pid, {:frame, last_frame}, [:nosuspend])
  end
end
