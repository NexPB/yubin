defmodule Yubin.Build do
  @moduledoc false

  alias Yubin.Build.Cleaner
  alias Yubin.Prefecture

  NimbleCSV.define(Yubin.Build.CSV, separator: ",", escape: "\"")

  @format 2

  @typedoc """
  The row stored per address: `{kind, prefecture_code, city, city_kana, town, town_kana,
  note, floor, business_name, street}`.
  """
  @type row ::
          {Yubin.Address.kind(), String.t(), String.t(), String.t() | nil, String.t(), String.t() | nil,
           String.t() | nil, pos_integer() | nil, String.t() | nil, String.t() | nil}

  @doc """
  Parses `utf_ken_all.csv` (UTF-8) into `{postal_code, row}` pairs, one per line.

  Raises when the line count and the parsed row count differ, or when a row's prefecture
  name does not match its local government code.
  """
  @spec ken_all(binary()) :: [{String.t(), row()}]
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
  @spec jigyosyo(binary(), [{String.t(), row()}]) :: [{String.t(), row()}]
  def jigyosyo(csv, ken_all) do
    kana = kana_index(ken_all)

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
  source file) and `:entries`, a list of `{postal_code, rows}` sorted by code, where `rows`
  is `[row]` encoded with `:erlang.term_to_binary/2`. Rows keep their source order, area
  rows first.
  """
  @spec encode([{String.t(), row()}], [{String.t(), row()}], Date.t()) :: binary()
  def encode(ken_all, jigyosyo, %Date{} = data_version) do
    entries =
      (ken_all ++ jigyosyo)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.map(fn {code, rows} -> {code, :erlang.term_to_binary(rows, [:deterministic])} end)
      |> Enum.sort()

    term = %{
      format: @format,
      data_version: data_version,
      source_rows: %{ken_all: length(ken_all), jigyosyo: length(jigyosyo)},
      entries: entries
    }

    :erlang.term_to_binary(term, [:deterministic, compressed: 9])
  end

  defp parse(csv), do: Yubin.Build.CSV.parse_string(csv, skip_headers: false)

  defp check_count!(rows, csv, file) do
    lines = csv |> :binary.matches("\n") |> length()
    lines = if String.ends_with?(csv, "\n"), do: lines, else: lines + 1

    if length(rows) != lines do
      raise "#{file}: #{lines} lines, but #{length(rows)} rows parsed"
    end

    rows
  end

  defp prefecture_code!(<<pref_code::binary-size(2), _::binary-size(3)>> = jis, name) do
    case Prefecture.from_code(pref_code) do
      %Prefecture{name: ^name} -> pref_code
      _ -> raise "local government code #{jis} does not belong to #{name}"
    end
  end

  # Maps {pref_code, city} and {pref_code, city, town} to the kana, for names with one reading.
  defp kana_index(ken_all) do
    ken_all
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

  defp add_reading(acc, key, kana) do
    Map.update(acc, key, [kana], fn readings ->
      if kana in readings, do: readings, else: [kana | readings]
    end)
  end
end
