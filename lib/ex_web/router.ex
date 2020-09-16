defmodule ExWeb.Router do
  alias ExWeb.{DocumentStore, Request, Response}

  @spec handle_request(Request.t()) :: {:ok, Response.t()}
  def handle_request(%Request{method: :get, route: "/"}) do
    {:ok,
     Response.new()
     |> Response.set_status(200)
     |> Response.add_body("Hello World!\n")
     |> Response.add_header("Content-Type", "text/plain")}
  end

  def handle_request(%Request{method: :post, route: route} = req) when route != "/" do
    with %{"content-type" => content_type} <- req.headers,
         data <- req.body do
      DocumentStore.store(route, {content_type, data})

      {:ok, no_content()}
    end
  end

  def handle_request(%Request{method: :delete, route: route}) when route != "/" do
    DocumentStore.delete(route)
    {:ok, no_content()}
  end

  def handle_request(%Request{method: :get, route: route}) do
    case DocumentStore.get(route) do
      {:ok, {content_type, data}} ->
        {:ok,
         Response.new()
         |> Response.set_status(200)
         |> Response.add_body(data)
         |> Response.add_header("Content-Type", content_type)}

      {:error, :not_found} ->
        {:ok, not_found()}
    end
  end

  def handle_request(_), do: {:ok, not_found()}

  defp not_found do
    Response.new()
    |> Response.set_status(404)
    |> Response.add_body("Not Found\n")
    |> Response.add_header("Content-Type", "text/plain")
  end

  defp no_content do
    Response.new()
    |> Response.set_status(204)
  end
end
