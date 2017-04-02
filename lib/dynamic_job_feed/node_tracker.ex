defmodule DynamicJobFeed.NodeTracker do
  @moduledoc """
  """

  @behaviour Phoenix.Tracker

  require Logger

  def start_link(opts) do
    opts = Keyword.merge([name: __MODULE__], opts)
    GenServer.start_link(Phoenix.Tracker, [__MODULE__, opts, opts], name: __MODULE__)
  end

  def node_list do
    Phoenix.Tracker.list(__MODULE__, "worker_nodes")
  end

  def init(opts) do
    server = Keyword.fetch!(opts, :pubsub_server)
    {:ok, %{pubsub_server: server, node_name: Phoenix.PubSub.node_name(server)}}
  end

  @doc """
  """
  def handle_diff(diff, state) do
    Task.Supervisor.start_child(DynamicJobFeed.NodeTrackerTaskSupervisor, fn ->
      for {topic, {joins, leaves}} <- diff do
        IO.puts "(crawler nodes) topic: #{topic}"
        # eIO.puts "    joins: #{inspect(joins)}"
        IO.puts "    leaves: #{inspect(leaves)}"
      end
    end)
    {:ok, state}
  end

end
