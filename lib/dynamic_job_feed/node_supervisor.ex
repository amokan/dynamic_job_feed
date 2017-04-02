defmodule DynamicJobFeed.NodeSupervisor do
    
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    children = [
      supervisor(Phoenix.PubSub.PG2, [:worker_nodes, []]),
      supervisor(Task.Supervisor, [[name: DynamicJobFeed.NodeTrackerTaskSupervisor]], id: :node_tracker_task_sup),
      worker(DynamicJobFeed.NodeTracker, [[name: DynamicJobFeed.NodeTracker, pubsub_server: :worker_nodes]]),
      worker(DynamicJobFeed.WorkerNode, [])
    ]

    supervise(children, strategy: :one_for_one)
  end

end
