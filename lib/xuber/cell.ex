defmodule XUber.Cell do
  use GenServer

  alias XUber.{Geometry, Grid}

  @cell_size Application.get_env(:xuber, :cell_size)

  def start_link(name, coordinates = {lat, lng}) do
    state = %{
      jurisdiction: {coordinates, {lat + @cell_size, lng + @cell_size}},
      pids: %{}
    }

    GenServer.start_link(__MODULE__, state, name: name)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call({:join, pid, coordinates, traits}, _from, state) do
    record = %{
      position: coordinates,
      traits: traits,
      ref: Process.monitor(pid)
    }

    {:reply, :ok, put_in(state[:pids][pid], record)}
  end

  def handle_call({:leave, pid}, _from, state) do
    {:reply, :ok, remove(state, pid)}
  end

  def handle_call({:update, pid, coordinates}, _from, state) do
    if Geometry.outside?(state.jurisdiction, coordinates) do
      Grid.join(pid, coordinates)

      {:reply, :ok, remove(state, pid)}
    else
      {:reply, :ok, put_in(state[:pids][pid][:position], coordinates)}
    end
  end

  def handle_call({:nearby, from, radius, filters}, _from, state) do
    results =
      state.pids
      |> Enum.into([])
      |> Enum.filter(fn {_pid, %{traits: traits}} -> subset?(traits, filters) end)
      |> Enum.map(fn {pid, %{position: to}} -> {pid, to, Geometry.distance(from, to)} end)
      |> Enum.filter(fn {_pid, _position, distance} -> distance < radius end)

    {:reply, {:ok, results}, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, remove(state, pid)}
  end

  defp remove(state, pid) do
    Process.demonitor(state.pids[pid].ref)

    %{state | pids: Map.delete(state.pids, pid)}
  end

  defp subset?(traits, filters) do
    traits = MapSet.new(traits)
    filters = MapSet.new(filters)

    MapSet.subset?(traits, filters)
  end
end
