defmodule DynamicJobFeed.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      supervisor(Registry, [:unique, :node_supervisor_registry], id: :instance_supervisor_registry),
      supervisor(DynamicJobFeed.NodeSupervisor, [])
      # Starts a worker by calling: DynamicJobFeed.Worker.start_link(arg1, arg2, arg3)
      # worker(DynamicJobFeed.Worker, [arg1, arg2, arg3]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DynamicJobFeed.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
