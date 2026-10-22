defmodule Yubin.Build.Cleaner do
  @moduledoc false

  @floor ~r/\A(?<name>.+)（(?:(?<floor>[０-９]+)階|地階・階層不明)）\z/u
  @bracket ~r/\A(?<name>.+?)（(?<note>.*)）\z/u

  @type cleaned :: %{
          kind: :area | :building,
          town: String.t(),
          town_kana: String.t(),
          note: String.t() | nil,
          floor: pos_integer() | nil
        }

  @doc """
  Cleans the KEN_ALL town name and its kana.

  `city` is the KEN_ALL city name, used to tell "{village}一円" from the place named 一円.
  """
  @spec clean(String.t(), String.t(), String.t()) :: cleaned()
  def clean(_city, "以下に掲載がない場合", _town_kana), do: whole_city()

  def clean(city, town, town_kana) do
    cond do
      String.ends_with?(town, "の次に番地がくる場合") -> whole_city()
      whole_village?(city, town) -> whole_city()
      true -> building(town, town_kana)
    end
  end

  @spec whole_city() :: cleaned()
  defp whole_city, do: %{kind: :area, town: "", town_kana: "", note: nil, floor: nil}

  # 滋賀県犬上郡多賀町 has a real town named 一円, so the prefix must be the city name.
  @spec whole_village?(String.t(), String.t()) :: boolean()
  defp whole_village?(city, town) do
    case String.split(town, "一円") do
      [village, ""] when village != "" -> String.ends_with?(city, village)
      _ -> false
    end
  end

  @spec building(String.t(), String.t()) :: cleaned()
  defp building(town, town_kana) do
    case Regex.named_captures(@floor, town) do
      %{"name" => name, "floor" => floor} ->
        %{bracket(name, town_kana) | kind: :building, floor: parse_floor(floor)}

      nil ->
        bracket(town, town_kana)
    end
  end

  @spec parse_floor(String.t()) :: pos_integer() | nil
  defp parse_floor(""), do: nil
  defp parse_floor(digits), do: digits |> :unicode.characters_to_nfkc_binary() |> String.to_integer()

  # The kana carries the same brackets in kana ("（１カイ）"), or none for the Kyoto street directions.
  @spec bracket(String.t(), String.t()) :: cleaned()
  defp bracket(town, town_kana) do
    kana = town_kana |> String.split("（", parts: 2) |> hd()

    case Regex.named_captures(@bracket, town) do
      %{"name" => name, "note" => note} -> %{kind: :area, town: name, town_kana: kana, note: note, floor: nil}
      nil -> %{kind: :area, town: town, town_kana: kana, note: nil, floor: nil}
    end
  end
end
