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
  @packed {__MODULE__, :packed}
  @cities {__MODULE__, :cities}

  # Stores the file of a layout and returns what unload/1 takes: an ETS table named
  # :"bench <layout>", or a persistent term key.
  def load({"packed", etf}) do
    :persistent_term.put(@packed, etf |> :erlang.binary_to_term() |> Map.take([:cities, :index, :rows]))
    @packed
  end

  def load({layout, etf}) do
    data = :erlang.binary_to_term(etf)
    if layout == "rows + cities", do: :persistent_term.put(@cities, data.cities)
    table = :ets.new(:"bench #{layout}", [:set, :protected, :named_table, read_concurrency: true])
    :ets.insert(table, data.entries)
    table
  end

  def unload(@packed), do: :persistent_term.erase(@packed)

  def unload(table) do
    :persistent_term.erase(@cities)
    :ets.delete(table)
  end

  # Returns {layout, file} pairs, built from the rows of the running application.
  def files do
    entries = Yubin.Table.entries()
    packed = Yubin.Build.pack(entries)
    offsets = for <<code::24, offset::32 <- packed.index>>, do: {code, offset}

    packed_rows =
      for [{code, offset}, {_next_code, next}] <- Enum.chunk_every(offsets, 2, 1, :discard),
          do: {code, binary_part(packed.rows, offset, next - offset)}

    blobs = for {code, rows} <- entries, do: {code, :erlang.term_to_binary(rows, [:deterministic])}
    rows = for {code, rows} <- entries, do: {code, Bench.Rows.encode(rows)}

    [
      {"tuples", file(%{entries: entries})},
      {"blob", file(%{entries: blobs})},
      {"blob integer", file(%{entries: integer_keys(blobs)})},
      {"rows", file(%{entries: integer_keys(rows)})},
      {"rows + cities", file(%{entries: packed_rows, cities: packed.cities})},
      {"packed", file(packed)}
    ]
  end

  defp file(term), do: :erlang.term_to_binary(term, [:deterministic, compressed: 9])
  defp integer_keys(entries), do: for({code, value} <- entries, do: {String.to_integer(code), value})

  def read_tuples(code), do: ets_read(:"bench tuples", code)
  def read_blob(code), do: :"bench blob" |> ets_read(code) |> :erlang.binary_to_term()

  def read_blob_integer(code),
    do: :"bench blob integer" |> ets_read(String.to_integer(code)) |> :erlang.binary_to_term()

  def read_rows(code), do: :"bench rows" |> ets_read(String.to_integer(code)) |> Bench.Rows.decode()

  def read_rows_cities(code) do
    :"bench rows + cities" |> ets_read(String.to_integer(code)) |> Yubin.Table.decode(:persistent_term.get(@cities))
  end

  def read_packed(code), do: Yubin.Table.rows(code, :persistent_term.get(@packed))

  defp ets_read(table, code), do: :ets.lookup_element(table, code, 2)

  # Returns how much ETS, binary and persistent term memory grow after a load, in bytes.
  # The binary growth counts each off-heap binary with its header, which :ets.info/2 leaves out.
  def footprint(input) do
    parent = self()
    before = usage()

    handle =
      Task.await(
        Task.async(fn ->
          handle = load(input)
          if is_atom(handle), do: :ets.give_away(handle, parent, nil)
          handle
        end)
      )

    receive do
      {:"ETS-TRANSFER", _table, _from, nil} -> :ok
    after
      0 -> :ok
    end

    growth = Enum.zip_with(usage(), before, &(&1 - &2))
    unload(handle)
    growth
  end

  # ETS frees a deleted table after a delay, so this waits until the usage stops changing.
  defp usage(previous \\ nil) do
    Enum.each(Process.list(), &:erlang.garbage_collect/1)
    current = [:erlang.memory(:ets), :erlang.memory(:binary), :persistent_term.info().memory]

    if previous && Enum.all?(Enum.zip_with(current, previous, &abs(&1 - &2)), &(&1 < 65_536)) do
      current
    else
      Process.sleep(50)
      usage(current)
    end
  end
end

# Kind, prefecture and floor bytes, then city, city kana, town, town kana, note, business
# name and street, each as a string of Yubin.Build.pack/1.
defmodule Bench.Rows do
  @kinds {:area, :building, :business}
  @prefectures Yubin.prefectures() |> Enum.map(& &1.code) |> List.to_tuple()

  def encode(rows), do: rows |> Enum.map(&encode_row/1) |> IO.iodata_to_binary()

  defp encode_row({kind, pref, city, city_kana, town, town_kana, note, floor, name, street}) do
    kind = Enum.find_index(Tuple.to_list(@kinds), &(&1 == kind))

    [
      kind,
      String.to_integer(pref),
      floor || 0 | Enum.map([city, city_kana, town, town_kana, note, name, street], &string/1)
    ]
  end

  defp string(nil), do: 255
  defp string(s) when byte_size(s) < 254, do: [byte_size(s), s]
  defp string(s), do: [254, <<byte_size(s)::16>>, s]

  def decode(<<>>), do: []

  def decode(<<kind, pref, floor, rest::binary>>) do
    {city, rest} = decode_string(rest)
    {city_kana, rest} = decode_string(rest)
    {town, rest} = decode_string(rest)
    {town_kana, rest} = decode_string(rest)
    {note, rest} = decode_string(rest)
    {name, rest} = decode_string(rest)
    {street, rest} = decode_string(rest)
    floor = if floor == 0, do: nil, else: floor

    row =
      {elem(@kinds, kind), elem(@prefectures, pref - 1), city, city_kana, town, town_kana, note, floor, name, street}

    [row | decode(rest)]
  end

  defp decode_string(<<255, rest::binary>>), do: {nil, rest}
  defp decode_string(<<254, size::16, s::binary-size(size), rest::binary>>), do: {s, rest}
  defp decode_string(<<size, s::binary-size(size), rest::binary>>), do: {s, rest}
end

defmodule Bench.Parse do
  @hyphens ~w(- ‐ ‒ – — ― ⁃ − ー)
  @spaces [" ", "\t", "\n", "\r"]

  def one_pass(input), do: Yubin.normalize(input)

  def string_replace(input) do
    input
    |> :unicode.characters_to_nfkc_binary()
    |> String.replace(@spaces, "")
    |> String.replace_prefix("〒", "")
    |> String.replace(@hyphens, "-")
    |> case do
      <<area::binary-size(3), ?-, number::binary-size(4)>> -> {:ok, area <> "-" <> number}
      <<area::binary-size(3), number::binary-size(4)>> -> {:ok, area <> "-" <> number}
      _ -> :error
    end
  end
end

Bench.decision("storage layout", [
  "Chosen: \"packed\" (format 3). Every row is in one binary in :persistent_term, with a sorted",
  "<<code::24, offset::32>> index that a lookup searches in about 17 steps, and a tuple of the",
  "1,892 {prefecture, city, city kana} that each row points to with 2 bytes.",
  "Rejected: one ETS entry per code, as \"tuples\", the \"blob\" of format 2, or blobs and rows",
  "with integer keys. Each of the 142,920 entries costs an ETS object of about 130 bytes, and each",
  "blob above 64 bytes an off-heap binary with its header, so even \"rows + cities\" holds 22 MiB.",
  "\"packed\" holds 7.7 MiB in place of 49 MiB for \"blob\", loads in 10 ms in place of 58 ms,",
  "reads 1 row as fast and 66 rows 4 times faster, because one match decodes a row."
])

layouts = Bench.Layout.files()

mib = fn bytes -> :erlang.float_to_binary(bytes / 1_048_576, decimals: 1) end

IO.puts("layout         file KiB  ETS MiB  binary MiB  persistent MiB  total MiB")

for {layout, file} <- layouts do
  [ets, binary, persistent] = Bench.Layout.footprint({layout, file})

  IO.puts(
    Enum.join(
      [
        String.pad_trailing(layout, 13),
        String.pad_leading("#{div(byte_size(file), 1024)}", 8),
        String.pad_leading(mib.(ets), 7),
        String.pad_leading(mib.(binary), 10),
        String.pad_leading(mib.(persistent), 14),
        String.pad_leading(mib.(ets + binary + persistent), 9)
      ],
      "  "
    )
  )
end

Benchee.run(%{"load" => &Bench.Layout.load/1},
  inputs: for({layout, file} <- layouts, do: {layout, {layout, file}}),
  after_each: &Bench.Layout.unload/1,
  warmup: 1,
  time: 5
)

Enum.each(layouts, &Bench.Layout.load/1)

Benchee.run(
  %{
    "read tuples" => &Bench.Layout.read_tuples/1,
    "read blob" => &Bench.Layout.read_blob/1,
    "read blob integer" => &Bench.Layout.read_blob_integer/1,
    "read rows" => &Bench.Layout.read_rows/1,
    "read rows + cities" => &Bench.Layout.read_rows_cities/1,
    "read packed" => &Bench.Layout.read_packed/1
  },
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
