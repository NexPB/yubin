# Benchmarks the public API and the application start.
#
#     mix run bench/runtime.exs --save   # writes the baseline, e.g. on main
#     mix run bench/runtime.exs          # compares with the baseline, e.g. on a branch
#
# Results depend on the machine, so bench/results/ is not committed.
# The budgets that fail CI are in test/yubin/benchmark_test.exs.

defmodule Bench.Runtime do
  # Jobs are module functions: closures in an .exs file run in the evaluator, which is
  # several times slower than compiled code.
  def lookup(input), do: Yubin.lookup(input)
  def normalize(input), do: Yubin.normalize(input)
  def start, do: {:ok, _} = Application.ensure_all_started(:yubin)

  def stop(input) do
    Application.stop(:yubin)
    input
  end

  def baseline(name) do
    path = "bench/results/#{name}.benchee"

    cond do
      "--save" in System.argv() -> [save: [path: path, tag: "baseline"]]
      File.exists?(path) -> [load: path]
      true -> []
    end
  end
end

# Application.stop/1 logs a notice per run.
Logger.configure(level: :warning)

Benchee.run(
  %{"lookup/1" => &Bench.Runtime.lookup/1, "normalize/1" => &Bench.Runtime.normalize/1},
  [
    inputs: [
      {"1 row", "5300001"},
      {"66 rows", "4520961"},
      {"full-width with 〒", "〒５３０－０００１"},
      {"not found", "0000000"},
      {"invalid", "530-001"}
    ],
    warmup: 1,
    time: 3,
    memory_time: 1
  ] ++ Bench.Runtime.baseline("api")
)

Benchee.run(
  %{"application start" => &Bench.Runtime.start/0},
  [before_each: &Bench.Runtime.stop/1, warmup: 1, time: 5] ++ Bench.Runtime.baseline("start")
)
