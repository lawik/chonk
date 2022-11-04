defmodule ChonkWeb.PageController do
  use ChonkWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def get(conn, _params) do
    form =
      "index.html"
      |> Chonk.Html.render(%{})

    Chonk.Chunker.call(conn,
      initial: form,
      connect_callback: &Chonk.Html.connect/2,
      wait_callback: &Chonk.Html.wait_callback/1
    )
  end

  def post(conn, %{"name" => name, "message" => message}) do
    form =
      "index.html"
      |> Chonk.Html.render(%{name: name})

    update =
      "update.html"
      |> Chonk.Html.render(%{name: name, message: message})

    Chonk.Chunker.call(conn,
      initial: form <> update,
      connect_callback: &Chonk.Html.connect/2,
      wait_callback: &Chonk.Html.wait_callback/1
    )
  end
end
