defmodule DynamicJobFeed.WorkerNode do
  @moduledoc """
  """

  use GenServer
  require Logger

  @tracker_channel "worker_nodes"
  # @worker_nodes_channel "worker_nodes:*"

  alias DynamicJobFeed.NodeTracker

  defstruct status: :unknown,
            node_id: nil,
            node_name: nil,
            host: nil,
            cpu_cores: 0,
            is_connected: false,
            version: nil,
            debug_mode: true,
            is_master: false,
            worker_nodes: []

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def node_joined(node_name) do
    GenServer.call(__MODULE__, {:node_joined, node_name})
  end

  def state do
    GenServer.call(__MODULE__, :get_state)
  end

  def init(_) do
    Process.flag(:trap_exit, true)

    send(self(), :check_master)

    Process.send_after(self(), :subscribe_and_track, 1_000)
    Process.send_after(self(), :indicate_ready, 2_000)

    with {_host, node_id} <- create_node_id(),
         node_name <- Node.self(),
         local_ip <- my_ip(),
         cpu_core_count <- :erlang.system_info(:logical_processors),
         initial_state <- %__MODULE__{ node_id: node_id, node_name: node_name, host: local_ip, status: :running, cpu_cores: cpu_core_count },
         do: {:ok, initial_state}
  end

  @doc """
  Callback to handle the `:subscribe_and_track` message

  This will cause the current process to register itself with the `ExWorkers.WorkerTask.InstanceTracker` as well as join a shared pubsub channel
  """
  def handle_info(:subscribe_and_track, %__MODULE__{ node_id: node_id, node_name: node_name, status: status, is_master: is_master } = state) do
    Phoenix.Tracker.track(NodeTracker, self(), @tracker_channel, node_id, %{ node_id: node_id, pid: self(), node_name: node_name, status: status, is_master: is_master, cpu_cores: state.cpu_cores, version: state.version })

    # subscribe to the specific channel for this node as well as the global channel
    Phoenix.PubSub.subscribe(:worker_nodes, "worker_nodes:#{node_id}")
    Phoenix.PubSub.subscribe(:worker_nodes, "worker_nodes:global")
    {:noreply, state}
  end

  def handle_info(:check_master, state) do
    if Node.self() == :"master@127.0.0.1" do
      Logger.info("is master")
      {:noreply, %__MODULE__{ state | is_master: true}}
    else
      Logger.info("is worker")
      {:noreply, %__MODULE__{ state | is_master: false}}
    end
  end

  def handle_info(:indicate_ready, %__MODULE__{ is_master: false } = state) do
    :rpc.call(:"master@127.0.0.1", DynamicJobFeed.WorkerNode, :node_joined, [Node.self()])
    {:noreply, state}
  end
  def handle_info(:indicate_ready, state), do: {:noreply, state}

  def handle_info({:nodedown, node_name}, %__MODULE__{ worker_nodes: [] } = state) do
    Logger.info("Node Down: #{inspect node_name}")
    {:noreply, state}
  end
  def handle_info({:nodedown, node_name}, %__MODULE__{ worker_nodes: worker_nodes } = state) do
    Logger.info("Node Down: #{inspect node_name}")

    {:noreply, %__MODULE__{ state | worker_nodes: Keyword.delete(worker_nodes, node_name) }}
  end

  def handle_call({:node_joined, node_name}, _from, %__MODULE__{ is_master: true, worker_nodes: worker_nodes } = state) do
    Logger.info("Node Joined - #{inspect node_name}")
    {:reply, :ok, %__MODULE__{ state | worker_nodes: [{node_name, Node.monitor(node_name, true)} | worker_nodes] }}
  end
  def handle_call({:node_joined, _node_name}, _from, %__MODULE__{ is_master: false } = state), do: {:reply, :ok, state}

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @doc """
  Callback to handle termination of this process
  """
  def terminate(:normal, state), do: {:noreply, untrack(state)}
  def terminate(:shutdown, state), do: {:noreply, untrack(state)}
  def terminate(reason, %__MODULE__{} = state) do
    Logger.warn(Poison.encode!(%{pid: inspect(self()), module: __MODULE__, msg: "Cluster Member Termination", node_id: state.node_id, status: inspect(state.status), reason: inspect(reason), node: inspect(Node.self) }))
    
    {:noreply, untrack(state)}
  end

  # stop tracking this process
  defp untrack(%__MODULE__{} = state) do
    if state.debug_mode, do: Logger.debug(Poison.encode!(%{pid: inspect(self()), module: __MODULE__, msg: "Untrack Cluster Member Node", node_id: state.node_id, status: inspect(state.status), node: inspect(Node.self) }))

    Phoenix.Tracker.untrack(NodeTracker, self(), @tracker_channel, state.node_id)
    state
  end

  # push any changes to the tracker
  defp push_state_changes(%__MODULE__{ node_id: node_id, status: status } = state) do
    Phoenix.Tracker.update(NodeTracker, self(), @tracker_channel, node_id, %{ node_id: node_id, pid: self(), node_name: state.node_name, status: status, cpu_cores: state.cpu_cores, version: state.version })
    state
  end

  # create a unique node identifier
  defp create_node_id do
    with {:ok, local_hostname} <- :inet.gethostname,
         hostname <- local_hostname |> to_string,
         ip <- my_ip(),
         do: {hostname, "#{hostname}__#{ip}"}
  end

  # determine the running version number of this application
  defp app_version_number do
    :application.which_applications
    |> Enum.filter(fn {app_name, _, _} -> app_name == :dynamic_job_feed end)
    |> Enum.map(fn {_, _, version} -> version end)
    |> List.first
    |> to_string
  end

  # determine the local IP address of the server we are running on
  defp my_ip do
    {:ok, ifs} = :inet.getif()
    ips = Enum.map(ifs, fn {ip, _broadaddr, _mask} -> ip end)
    ip_tuple = ips |> List.first
    "#{elem(ip_tuple, 0)}.#{elem(ip_tuple, 1)}.#{elem(ip_tuple, 2)}.#{elem(ip_tuple, 3)}"
  end

end
