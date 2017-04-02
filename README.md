# DynamicJobFeed

Just a project for experimenting with some distributed task and node monitoring.

Mostly a simple example for myself at a later date.

## Start Nodes
```
iex --name master@127.0.0.1 --erl "-config sys.config" -S mix

iex --name crawler1@127.0.0.1 --erl "-config sys.config" -S mix

iex --name foo@127.0.0.1 --erl "-config sys.config" -S mix
```

## View the distributed node list

```
DynamicJobFeed.NodeTracker.node_list()
```

## Handle disconnect of worker node(s)

If you stop the VM on any of the nodes other than `:"master@127.0.0.1"`, you should see the master node monitor kick in on line 82 of worker_node.ex (` handle_info({:nodedown, node_name}, state)`)
