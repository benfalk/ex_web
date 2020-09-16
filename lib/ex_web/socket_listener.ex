defmodule ExWeb.SocketListener do
  use GenServer
  require Logger
  alias ExWeb.Server

  defstruct port_number: 8080,
            socket: nil,
            listener: nil

  def start_link(port_num) do
    GenServer.start_link(__MODULE__, port_num)
  end

  ## GenServer Callbacks

  def init(port_num) do
    {:ok, socket} = :gen_tcp.listen(port_num, [:binary, active: false, reuseaddr: true])
    listener = Task.start_link(fn -> listen(socket) end)
    Logger.debug("Accepting new connections on port #{port_num}")
    {:ok, %__MODULE__{port_number: port_num, socket: socket, listener: listener}}
  end

  ## Private Functions

  defp listen(socket) do
    {:ok, port} = :gen_tcp.accept(socket)
    Server.serve(port)
    listen(socket)
  end
end
