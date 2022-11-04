defmodule Chonk.Chunker do
  @moduledoc """
  Documentation for `Mjpeg`.
  """

  import Plug.Conn
  require Logger

  @boundary "w58EW1cEpjzydSCq"

  def init(opts), do: opts

  def call(conn, opts) do
    connect = Keyword.get(opts, :connect_callback, nil)
    wait = Keyword.get(opts, :wait_callback, nil)

    if is_nil(connect) or is_nil(wait) do
      raise "Need both :connect_callback and :wait_callback in options."
    end

    context = connect.(conn, opts)

    conn
    |> send_start()
    |> wait_for_frame(wait, context)
  end

  def send_frame(conn, mime_type, data, context) do
    size = byte_size(data)

    # header = "------#{@boundary}\r\nContent-Type: #{mime_type}\r\nContent-length: #{size}\r\n\r\n"
    header = ""
    footer = "\r\n"

    with {:ok, conn} <- chunk(conn, header),
         {:ok, conn} <- chunk(conn, data),
         {:ok, conn} <- chunk(conn, footer) do
      Logger.info("Frame sent: #{inspect(self())}")
      conn
    else
      _ ->
        context.error_callback()
    end
  end

  defp wait_for_frame(conn, wait, context) do
    {mime_type, frame} = wait.(context)

    conn
    |> send_frame(mime_type, frame, context)
    |> wait_for_frame(wait, context)
  end

  defp send_start(conn) do
    conn
    |> put_resp_header("Age", "0")
    |> put_resp_header("Cache-Control", "no-cache, private")
    |> put_resp_header("Pragma", "no-cache")
    |> put_resp_header("Content-Type", "text/html; boundary=#{@boundary}")
    |> send_chunked(200)
  end
end
