defmodule Aggregator do
  use GenServer

  @group_limit 5
  @queue_limit 3
  
  @doc """
  Shows the problem with uneven awekings of queues in a high demand situation.
  
  It starts _nqueues_ of queus with a rate limit, all belonging to a group, also
  rate limited. Then it starts _nproc_ processes per each queue. All processes
  try to access their respected queue and once it's granted they send a message
  to Aggregator gen_server. Aggregator will display a report once all messages
  has been sent.
  """
  def test(nqueue, nproc) do
    {:ok, pid} = Aggregator.start_link {nqueue, nproc}
    :jobs.add_group_rate :gq, limit: @group_limit

    queue_names = 0..(nqueue-1) |> Enum.to_list
    for q <- queue_names do
      :jobs.add_queue q,
        regulators: [group_rate: :gq, rate: [limit: @queue_limit]],
        mod: :jobs_queue_list
    end

    for _ <- 1..nproc, q <- queue_names do
      spawn fn -> :jobs.run(q, fn -> send pid, {q, :erlang.time} end) end;
    end

    Process.sleep 100
    wait_for_finish(nproc)
  end

  defp wait_for_finish(nproc) do
    distribution = sum_up()
    {_time, queues_fulfilment, _events} = List.last distribution
    reduced_qf =
      queues_fulfilment
      |> Tuple.to_list
      |> Enum.dedup

    if [nproc] == reduced_qf do
      distribution
    else
      Process.sleep 500
      wait_for_finish(nproc)
    end
  end

  # Client API
  def start_link({nqueue, nproc}) do
    GenServer.start_link(__MODULE__, {nqueue, nproc}, name: __MODULE__)
  end

  def stop do
    GenServer.stop __MODULE__
  end

  def sum_up() do
    GenServer.call(__MODULE__, :sum_up)
  end

  # Server callbacks
  def init({nqueue, nproc}) do
    {:ok, {nqueue, nproc, %{}}}
  end

  def handle_call(:sum_up, _from, {nqueue, nproc, events}) do
    rolling_update = fn qs, ru ->
      Enum.reduce(qs, ru, fn q, acc ->
        update_in acc, [Access.elem(q)], & &1+1
      end)
    end

    acc0 = List.duplicate(0, nqueue) |> List.to_tuple
    {distribution, _} =
      events
      |> Enum.sort
      |> Enum.map_reduce(acc0, fn {t, qs}, acc ->
           ru = rolling_update.(qs, acc)
           {{t, ru, qs}, ru}
         end)

    {:reply, distribution, {nqueue, nproc, events}}
  end

  def handle_info({q, time}, {nqueue, nproc, events}) do
    events = Map.update(events, time, [q], fn qs -> [q|qs] end)
    
    {:noreply, {nqueue, nproc, events}}
  end
end
