defmodule Yubin.BenchmarkTest do
  # Stops and starts the application, so it must not run alongside other tests.
  use ExUnit.Case, async: false

  @moduletag :benchmark
  @moduletag timeout: :timer.minutes(2)

  # Time budgets are about 5x the medians on an Apple M1 Pro, to leave room for slower CI runners.
  # Memory does not depend on the machine, so its budgets are about 1.25x the measurement.

  test "lookup/1 of a code with 1 row" do
    assert_within(fn -> Yubin.lookup("5300001") end, time_us: 5, memory_kb: 3)
  end

  test "lookup/1 of 4520961, the code with the most rows (66)" do
    assert_within(fn -> Yubin.lookup("4520961") end, time_us: 80, memory_kb: 32)
  end

  test "lookup/1 of full-width input with 〒" do
    assert_within(fn -> Yubin.lookup("〒５３０－０００１") end, time_us: 8, memory_kb: 4.7)
  end

  test "normalize/1" do
    assert_within(fn -> Yubin.normalize("5300001") end, time_us: 3, memory_kb: 1.6)
  end

  @tag :capture_log
  test "the application starts within 300 ms" do
    stop = fn input ->
      Application.stop(:yubin)
      input
    end

    %{time: time} = measure(fn -> Application.ensure_all_started(:yubin) end, before_each: stop, time: 3)
    {:ok, _} = Application.ensure_all_started(:yubin)

    assert time <= 300_000_000, "median start #{Float.round(time / 1_000_000, 1)} ms"
  end

  test "the data holds 9.7 MiB at most" do
    data = :persistent_term.get(Yubin.Table)
    # :erts_debug.size/1 counts an off-heap binary as its reference only.
    term = :erts_debug.size(data) * :erlang.system_info(:wordsize)
    bytes = term + byte_size(data.index) + byte_size(data.rows)

    assert bytes <= 9.7 * 1_048_576, "#{Float.round(bytes / 1_048_576, 2)} MiB"
  end

  defp assert_within(fun, time_us: time_us, memory_kb: memory_kb) do
    %{time: time, memory: memory} = measure(fun, memory_time: 0.5)

    assert time <= time_us * 1_000, "median #{time} ns, budget #{time_us} µs"
    assert memory <= memory_kb * 1_024, "median #{memory} B, budget #{memory_kb} KB"
  end

  # Returns the median run time in ns and the median memory in bytes.
  defp measure(fun, opts) do
    opts =
      Keyword.merge([warmup: 0.5, time: 2, formatters: [], print: [benchmarking: false, configuration: false]], opts)

    %{scenarios: [scenario]} = Benchee.run(%{"job" => fun}, opts)

    %{
      time: scenario.run_time_data.statistics.median,
      memory: scenario.memory_usage_data.statistics.median
    }
  end
end
