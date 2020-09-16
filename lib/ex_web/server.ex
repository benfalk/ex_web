defmodule ExWeb.Server do
  require Logger
  require IEx

  use GenServer, restart: :transient, shutdown: 1_000

  alias ExWeb.{Request, Response, Router}
  alias __MODULE__, as: Server

  defstruct port: nil,
            buffer: <<>>,
            request: Request.new()

  def serve(port) do
    {:ok, server} = GenServer.start(Server, port)
    :ok = :gen_tcp.controlling_process(port, server)
    GenServer.cast(server, :service_request)
  end

  ## GenServer Callbacks

  def init(port) do
    {:ok, %Server{port: port}}
  end

  def handle_continue(:request_loaded, %Server{request: req} = state) do
    with {:ok, resp} <- Router.handle_request(req),
         {:ok, keep_alive?, resp} <- keep_alive(resp, req),
         {:ok, bin} <- Response.to_binary(resp),
         :ok <- :gen_tcp.send(state.port, bin) do
      if keep_alive? do
        {:noreply, %{state | request: Request.new()}}
      else
        {:stop, :normal, state}
      end
    else
      {:error, error} ->
        {:stop, error, state}
    end
  end

  def handle_cast(:service_request, %Server{port: port} = state) do
    case :inet.setopts(port, active: :once, buffer: 120_000) do
      :ok ->
        {:noreply, state}

      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  def handle_info({:tcp, port, bin}, %Server{port: port} = state) do
    with {:ok, req, buffer} <- Request.load(state.request, state.buffer <> bin),
         :ok <- :inet.setopts(port, active: :once) do
      if req.loaded? do
        {:noreply, %{state | request: req, buffer: buffer}, {:continue, :request_loaded}}
      else
        {:noreply, %{state | request: req, buffer: buffer}}
      end
    else
      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  def handle_info({:tcp_closed, port}, %Server{port: port} = state) do
    {:stop, :normal, state}
  end

  ## Private Functions

  defp keep_alive(resp, %Request{headers: %{"connection" => "Keep-Alive"}}) do
    {:ok, true,
     resp
     |> Response.add_header("Keep-Alive", "timeout=5,max=20000")
     |> Response.add_header("Connection", "Keep-Alive")}
  end

  defp keep_alive(resp, _) do
    {:ok, false, resp}
  end
end
