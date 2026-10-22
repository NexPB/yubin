defmodule Yubin.Build do
  @moduledoc false

  import Bitwise

  alias Yubin.Build.Cleaner
  alias Yubin.Prefecture
  alias Yubin.Table

  NimbleCSV.define(Yubin.Build.CSV, separator: ",", escape: "\"")

  @max_cities 0x10000

  @typep city_index :: %{{String.t(), String.t(), String.t() | nil} => non_neg_integer()}

  @doc """
  Parses `utf_ken_all.csv` (UTF-8) into `{postal_code, row}` pairs, one per line.

  Raises when the line count and the parsed row count differ, or when a row's prefecture
  name does not match its local government code.
  """
  @spec ken_all(binary()) :: [{String.t(), Table.row()}]
  def ken_all(csv) do
    csv
    |> parse()
    |> Enum.map(fn [jis, _old, code, _pref_kana, city_kana, town_kana, pref, city, town | _flags] ->
      pref_code = prefecture_code!(jis, pref)
      c = Cleaner.clean(city, town, town_kana)
      {code, {c.kind, pref_code, city, city_kana, c.town, c.town_kana, c.note, c.floor, nil, nil}}
    end)
    |> check_count!(csv, "utf_ken_all.csv")
  end

  @doc """
  Parses `JIGYOSYO.CSV`, already decoded to UTF-8, into `{postal_code, row}` pairs.

  The file has no kana for the city and town, so they are taken from the `ken_all/1` rows
  with the same names, and are `nil` when those rows have no single reading.
  """
  @spec jigyosyo(binary(), [{String.t(), Table.row()}]) :: [{String.t(), Table.row()}]
  def jigyosyo(csv, ken_all_rows) do
    kana = kana_index(ken_all_rows)

    csv
    |> parse()
    |> Enum.map(fn [jis, _name_kana, name, pref, city, town, street, code | _rest] ->
      pref_code = prefecture_code!(jis, pref)
      city_kana = kana[{pref_code, city}]
      town_kana = kana[{pref_code, city, town}]

      {code, {:business, pref_code, city, city_kana, town, town_kana, nil, nil, name, street}}
    end)
    |> check_count!(csv, "JIGYOSYO.CSV")
  end

  @doc """
  Encodes the rows into the binary of `priv/postal.etf`.

  The term is a map with `:format`, `:data_version`, `:source_rows` (line count of each
  source file) and the fields of `pack/1`. Rows keep their source order, area rows first.
  """
  @spec encode([{String.t(), Table.row()}], [{String.t(), Table.row()}], Date.t()) :: binary()
  def encode(ken_all_rows, jigyosyo_rows, %Date{} = data_version) do
    entries = (ken_all_rows ++ jigyosyo_rows) |> Enum.group_by(&elem(&1, 0), &elem(&1, 1)) |> Enum.sort()

    term =
      Map.merge(pack(entries), %{
        format: Table.format(),
        data_version: data_version,
        source_rows: %{ken_all: length(ken_all_rows), jigyosyo: length(jigyosyo_rows)}
      })

    :erlang.term_to_binary(term, [:deterministic, compressed: 9])
  end

  @doc """
  Packs `{postal_code, rows}` pairs, sorted by code, into the fields that `Yubin.Table` reads.

    * `:cities` - a tuple of the distinct `{prefecture_code, city, city_kana}`
    * `:rows` - the rows of every code, in code order, as one binary
    * `:index` - `<<code::24, offset::32>>` per code, where `offset` is the start of its rows,
      then `<<0xFFFFFF::24, byte_size(rows)::32>>`

  A row starts with `<<kind::6, nil_town_kana::1, nil_note::1, city_index::16>>`, where kind is
  0 for `:area`, 1 for `:building` and 2 for `:business`. Then come the sizes of its strings,
  then the strings:

    * `:area` - `<<town, town_kana, note::16>>`
    * `:building` - `<<floor, town, town_kana, note::16>>`, with floor 0 for `nil`
    * `:business` - `<<town, town_kana, business_name, street>>`

  A `nil` string has size 0.

  Raises when a string is longer than its size allows, or when there are over 65,536 cities.
  """
  @spec pack([{String.t(), [Table.row()]}]) :: Table.data()
  def pack(entries) do
    cities = Enum.uniq(for {_code, rows} <- entries, row <- rows, do: {elem(row, 1), elem(row, 2), elem(row, 3)})
    city_index = cities |> Enum.with_index() |> Map.new()

    if map_size(city_index) > @max_cities do
      raise "#{map_size(city_index)} cities, over the #{@max_cities} that a 16-bit city index allows"
    end

    {index, rows, size} =
      Enum.reduce(entries, {[], [], 0}, fn {code, rows}, {index, acc, offset} ->
        packed = rows |> Enum.map(&pack_row(&1, code, city_index)) |> IO.iodata_to_binary()
        {[<<String.to_integer(code)::24, offset::32>> | index], [packed | acc], offset + byte_size(packed)}
      end)

    %{
      cities: List.to_tuple(cities),
      index: IO.iodata_to_binary(Enum.reverse(index, [<<0xFFFFFF::24, size::32>>])),
      rows: rows |> Enum.reverse() |> IO.iodata_to_binary()
    }
  end

  @spec pack_row(Table.row(), String.t(), city_index()) :: iodata()
  defp pack_row({:area, pref, city, city_kana, town, town_kana, note, nil, nil, nil}, code, city_index) do
    header = <<0::6, nil?(town_kana)::1, nil?(note)::1, pack_city(city_index, pref, city, city_kana)::binary>>

    [
      header,
      string_size(code, :town, town),
      string_size(code, :town_kana, town_kana),
      string_size(code, :note, note, 16),
      town,
      town_kana || "",
      note || ""
    ]
  end

  defp pack_row({:building, pref, city, city_kana, town, town_kana, note, floor, nil, nil}, code, city_index)
       when floor in 1..255 or is_nil(floor) do
    header = <<1::6, nil?(town_kana)::1, nil?(note)::1, pack_city(city_index, pref, city, city_kana)::binary>>

    [
      header,
      floor || 0,
      string_size(code, :town, town),
      string_size(code, :town_kana, town_kana),
      string_size(code, :note, note, 16),
      town,
      town_kana || "",
      note || ""
    ]
  end

  defp pack_row({:business, pref, city, city_kana, town, town_kana, nil, nil, name, street}, code, city_index) do
    header = <<2::6, nil?(town_kana)::1, 1::1, pack_city(city_index, pref, city, city_kana)::binary>>

    [
      header,
      string_size(code, :town, town),
      string_size(code, :town_kana, town_kana),
      string_size(code, :business_name, name),
      string_size(code, :street, street),
      town,
      town_kana || "",
      name,
      street
    ]
  end

  @spec pack_city(city_index(), String.t(), String.t(), String.t() | nil) :: binary()
  defp pack_city(city_index, pref, city, city_kana), do: <<Map.fetch!(city_index, {pref, city, city_kana})::16>>

  @spec nil?(String.t() | nil) :: 0 | 1
  defp nil?(nil), do: 1
  defp nil?(_string), do: 0

  @spec string_size(String.t(), atom(), String.t() | nil, 8 | 16) :: binary()
  defp string_size(code, field, string, bits \\ 8)
  defp string_size(_code, _field, nil, bits), do: <<0::size(bits)>>

  defp string_size(_code, _field, string, bits) when byte_size(string) < 1 <<< bits,
    do: <<byte_size(string)::size(bits)>>

  defp string_size(code, field, string, bits) do
    raise "#{code}: #{field} is #{byte_size(string)} bytes, over the #{(1 <<< bits) - 1} that its size allows"
  end

  @spec parse(binary()) :: [[String.t()]]
  defp parse(csv), do: Yubin.Build.CSV.parse_string(csv, skip_headers: false)

  @spec check_count!([{String.t(), Table.row()}], binary(), String.t()) :: [{String.t(), Table.row()}]
  defp check_count!(rows, csv, file) do
    lines = csv |> :binary.matches("\n") |> length()
    lines = if String.ends_with?(csv, "\n"), do: lines, else: lines + 1

    if length(rows) != lines do
      raise "#{file}: #{lines} lines, but #{length(rows)} rows parsed"
    end

    rows
  end

  @spec prefecture_code!(String.t(), String.t()) :: String.t()
  defp prefecture_code!(<<pref_code::binary-size(2), _::binary-size(3)>> = jis, name) do
    case Prefecture.from_code(pref_code) do
      %Prefecture{name: ^name} -> pref_code
      _ -> raise "local government code #{jis} does not belong to #{name}"
    end
  end

  # Maps {pref_code, city} and {pref_code, city, town} to the kana, for names with one reading.
  @spec kana_index([{String.t(), Table.row()}]) :: %{tuple() => String.t() | nil}
  defp kana_index(ken_all_rows) do
    ken_all_rows
    |> Enum.reduce(%{}, fn {_code, row}, acc ->
      {_kind, pref, city, city_kana, town, town_kana, _note, _floor, _name, _street} = row

      acc
      |> add_reading({pref, city}, city_kana)
      |> add_reading({pref, city, town}, town_kana)
    end)
    |> Enum.flat_map(fn
      {key, [kana]} -> [{key, kana}]
      _ambiguous -> []
    end)
    |> Map.new()
  end

  @spec add_reading(%{tuple() => [String.t() | nil]}, tuple(), String.t() | nil) :: %{tuple() => [String.t() | nil]}
  defp add_reading(acc, key, kana) do
    Map.update(acc, key, [kana], fn readings ->
      if kana in readings, do: readings, else: [kana | readings]
    end)
  end
end
