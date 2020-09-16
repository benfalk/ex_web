defmodule ExWeb.DocumentStore do
  use GenServer
  require Logger

  alias __MODULE__, as: DocumentStore
  @tablename DocumentStore

  def start_link(_) do
    GenServer.start_link(DocumentStore, @tablename, name: DocumentStore)
  end

  def store(key, value) do
    GenServer.cast(DocumentStore, {:store, key, value})
  end

  def get(key) do
    case :ets.lookup(@tablename, key) do
      [{^key, value}] -> {:ok, value}
      [] -> {:error, :not_found}
    end
  end

  def delete(key) do
    GenServer.cast(DocumentStore, {:delete, key})
  end

  ## GenServer Callbacks

  def init(_) do
    :ets.new(@tablename, [:set, :protected, :named_table, read_concurrency: true])
    Logger.debug("Document Store Started")
    {:ok, %{}}
  end

  def handle_cast({:store, key, value}, state) do
    :ets.insert(@tablename, {key, value})
    {:noreply, state}
  end

  def handle_cast({:delete, key}, state) do
    :ets.delete(@tablename, key)
    {:noreply, state}
  end
end
