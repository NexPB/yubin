defmodule Yubin.Table do
  @moduledoc false

  @key __MODULE__
  @format 3
  @entry_size 7

  @spec load() :: :ok
  def load do
    path = Application.app_dir(:yubin, "priv/postal.etf")
    %{format: @format} = data = path |> File.read!() |> :erlang.binary_to_term()
    :persistent_term.put(@key, Map.take(data, [:data_version, :cities, :index, :rows]))
  end

  # Erasing makes every process that still references the term copy it, so do it only on stop.
  @spec unload() :: boolean()
  def unload, do: :persistent_term.erase(@key)

  @spec rows(String.t()) :: [tuple()]
  def rows(code), do: rows(code, :persistent_term.get(@key))

  @doc """
  Returns the rows of a 7-digit code in `data`, the term that `load/0` stores.

  The strings are sub-binaries of `data.rows`, or literals of `data.cities`.
  """
  @spec rows(String.t(), map()) :: [tuple()]
  def rows(code, %{index: index, rows: rows, cities: cities}) do
    last = div(byte_size(index), @entry_size) - 2

    case search(index, String.to_integer(code), 0, last) do
      {offset, size} -> decode(binary_part(rows, offset, size), cities)
      nil -> []
    end
  end

  @doc "Decodes rows packed by `Yubin.Build.pack/1`, with the cities of the same pack."
  @spec decode(binary(), tuple()) :: [tuple()]
  def decode(<<>>, _cities), do: []

  # One pattern per row lets the compiler keep one match context for the whole binary.
  def decode(
        <<0::6, nil_kana::1, nil_note::1, city::16, town_size, kana_size, note_size::16, town::binary-size(town_size),
          kana::binary-size(kana_size), note::binary-size(note_size), rest::binary>>,
        cities
      ) do
    row = row(:area, elem(cities, city), town, nilify(nil_kana, kana), nilify(nil_note, note), nil, nil, nil)
    [row | decode(rest, cities)]
  end

  def decode(
        <<1::6, nil_kana::1, nil_note::1, city::16, floor, town_size, kana_size, note_size::16,
          town::binary-size(town_size), kana::binary-size(kana_size), note::binary-size(note_size), rest::binary>>,
        cities
      ) do
    floor = if floor == 0, do: nil, else: floor
    row = row(:building, elem(cities, city), town, nilify(nil_kana, kana), nilify(nil_note, note), floor, nil, nil)
    [row | decode(rest, cities)]
  end

  def decode(
        <<2::6, nil_kana::1, _nil_note::1, city::16, town_size, kana_size, name_size, street_size,
          town::binary-size(town_size), kana::binary-size(kana_size), name::binary-size(name_size),
          street::binary-size(street_size), rest::binary>>,
        cities
      ) do
    row = row(:business, elem(cities, city), town, nilify(nil_kana, kana), nil, nil, name, street)
    [row | decode(rest, cities)]
  end

  @doc "Returns every `{code, rows}` in code order."
  @spec entries() :: [{String.t(), [tuple()]}]
  def entries do
    data = :persistent_term.get(@key)

    for <<code::24, _offset::32 <- data.index>>, code != 0xFFFFFF do
      code = code |> Integer.to_string() |> String.pad_leading(7, "0")
      {code, rows(code, data)}
    end
  end

  @spec data_version() :: Date.t()
  def data_version, do: :persistent_term.get(@key).data_version

  # Returns {offset, size} of the rows of the code. An entry's rows end where the next entry's start.
  defp search(_index, _code, low, high) when low > high, do: nil

  defp search(index, code, low, high) do
    mid = div(low + high, 2)
    skip = mid * @entry_size

    case index do
      <<_::binary-size(^skip), ^code::24, offset::32, _::24, next::32, _::binary>> -> {offset, next - offset}
      <<_::binary-size(^skip), other::24, _::binary>> when other < code -> search(index, code, mid + 1, high)
      _ -> search(index, code, low, mid - 1)
    end
  end

  defp nilify(1, _string), do: nil
  defp nilify(0, string), do: string

  defp row(kind, {pref, city, city_kana}, town, town_kana, note, floor, name, street) do
    {kind, pref, city, city_kana, town, town_kana, note, floor, name, street}
  end
end
