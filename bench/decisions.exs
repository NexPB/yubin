# Benchmarks the alternatives to two design decisions, so they can be measured again.
#
#     mix run bench/decisions.exs

defmodule Bench do
  def decision(title, lines) do
    IO.puts("\n== Decision: #{title}")
    Enum.each(lines, &IO.puts("   " <> &1))
    IO.puts("")
  end
end

defmodule Bench.Layout do
  def load(file) do
    table = :ets.new(:bench_load, [:set, :protected, read_concurrency: true])
    :ets.insert(table, :erlang.binary_to_term(file).entries)
    table
  end

  def read_tuples(code) do
    case :ets.lookup(:bench_tuples, code) do
      [{_code, rows}] -> rows
      [] -> []
    end
  end

  def read_blob(code) do
    case :ets.lookup(:bench_blob, code) do
      [{_code, rows}] -> :erlang.binary_to_term(rows)
      [] -> []
    end
  end

  # Returns {ets_bytes, off_heap_bytes}. Binaries over 64 bytes live off-heap, and
  # :ets.info/2 does not count them.
  def footprint(file) do
    parent = self()
    :erlang.garbage_collect()
    before = :erlang.memory(:binary)

    table =
      Task.await(
        Task.async(fn ->
          table = load(file)
          :ets.give_away(table, parent, nil)
          table
        end)
      )

    receive do
      {:"ETS-TRANSFER", ^table, _from, nil} -> :ok
    end

    :erlang.garbage_collect()
    footprint = {:ets.info(table, :memory) * :erlang.system_info(:wordsize), :erlang.memory(:binary) - before}
    :ets.delete(table)
    footprint
  end
end

defmodule Bench.Parse do
  @hyphens ~w(- ‐ ‒ – — ― ⁃ − ー)
  @spaces [" ", "\t", "\n", "\r"]

  def one_pass(input), do: Yubin.normalize(input)

  def string_replace(input) do
    case input
         |> :unicode.characters_to_nfkc_binary()
         |> String.replace(@spaces, "")
         |> String.replace_prefix("〒", "")
         |> String.replace(@hyphens, "-") do
      <<area::binary-size(3), ?-, number::binary-size(4)>> -> {:ok, area <> "-" <> number}
      <<area::binary-size(3), number::binary-size(4)>> -> {:ok, area <> "-" <> number}
      _ -> :error
    end
  end
end

Bench.decision("ETS layout", [
  "Chosen: one term_to_binary blob of rows per code (format 2). Rejected: a list of row tuples per code.",
  "Blobs load faster and use less memory in total. :ets.info/2 shows less than half of their memory,",
  "the rest is off-heap binaries. Reads must decode the blob, so they are slower, but they stay in",
  "microseconds, which a lookup from a form does not notice. Switch to tuples if read latency comes",
  "to matter more than start time and memory."
])

data = Application.app_dir(:yubin, "priv/postal.etf") |> File.read!() |> :erlang.binary_to_term()
tuple_entries = for {code, rows} <- data.entries, do: {code, :erlang.binary_to_term(rows)}

files = %{
  "blob" => :erlang.term_to_binary(data, [:deterministic, compressed: 9]),
  "tuples" => :erlang.term_to_binary(%{data | entries: tuple_entries}, [:deterministic, compressed: 9])
}

mib = fn bytes -> :erlang.float_to_binary(bytes / 1_048_576, decimals: 1) end

IO.puts("layout  file KiB  ETS MiB  off-heap MiB  total MiB")

for {layout, file} <- files do
  {ets, off_heap} = Bench.Layout.footprint(file)

  IO.puts(
    Enum.join(
      [
        String.pad_trailing(layout, 6),
        String.pad_leading("#{div(byte_size(file), 1024)}", 8),
        String.pad_leading(mib.(ets), 7),
        String.pad_leading(mib.(off_heap), 12),
        String.pad_leading(mib.(ets + off_heap), 9)
      ],
      "  "
    )
  )
end

Benchee.run(%{"load" => &Bench.Layout.load/1},
  inputs: files,
  after_each: &:ets.delete/1,
  warmup: 1,
  time: 5
)

:ets.new(:bench_tuples, [:set, :protected, :named_table, read_concurrency: true])
:ets.insert(:bench_tuples, tuple_entries)
:ets.new(:bench_blob, [:set, :protected, :named_table, read_concurrency: true])
:ets.insert(:bench_blob, data.entries)

Benchee.run(%{"read tuples" => &Bench.Layout.read_tuples/1, "read blob" => &Bench.Layout.read_blob/1},
  inputs: [{"1 row", "5300001"}, {"66 rows", "4520961"}],
  warmup: 1,
  time: 3,
  memory_time: 1
)

Bench.decision("input parser", [
  "Chosen: one pass over the NFKC output that drops spaces and maps every hyphen to \"-\".",
  "Rejected: String.replace/3 with lists of patterns, which compiles the patterns again on every",
  "call and costs several microseconds per lookup."
])

Benchee.run(%{"one pass" => &Bench.Parse.one_pass/1, "String.replace/3" => &Bench.Parse.string_replace/1},
  inputs: [{"ASCII", "5300001"}, {"full-width with 〒", "〒５３０－０００１"}],
  warmup: 1,
  time: 3,
  memory_time: 1
)
