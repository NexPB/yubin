defmodule Yubin.DataTest do
  use ExUnit.Case, async: true

  setup_all do
    data = "priv/postal.etf" |> File.read!() |> :erlang.binary_to_term()
    data = Map.put(data, :entries, Yubin.Table.entries())
    rows = for {code, rows} <- data.entries, row <- rows, do: {code, row}
    %{data: data, rows: rows}
  end

  defp count(rows, kinds), do: Enum.count(rows, fn {_code, row} -> elem(row, 0) in kinds end)

  test "every source row is in the build", %{data: data, rows: rows} do
    assert data.format == 3
    assert count(rows, [:area, :building]) == data.source_rows.ken_all
    assert count(rows, [:business]) == data.source_rows.jigyosyo
    assert length(rows) == data.source_rows.ken_all + data.source_rows.jigyosyo
  end

  test "entries are sorted, unique 7-digit codes", %{data: data} do
    codes = Enum.map(data.entries, &elem(&1, 0))
    assert codes == codes |> Enum.uniq() |> Enum.sort()
    assert Enum.all?(codes, &(&1 =~ ~r/\A\d{7}\z/))
  end

  test "no area name contains a bracket", %{rows: rows} do
    for {code, {kind, _, city, city_kana, town, town_kana, _, _, _, _}} <- rows,
        kind != :business,
        name <- [city, city_kana, town, town_kana] do
      refute name =~ ~r/[（）()]/u, "#{code}: #{name}"
    end
  end

  test "every row has one of the 47 prefectures", %{rows: rows} do
    codes = rows |> Enum.map(fn {_, row} -> elem(row, 1) end) |> Enum.uniq() |> Enum.sort()
    assert codes == Enum.map(Yubin.prefectures(), & &1.code)
  end

  test "the codes that cover two prefectures keep both", %{data: data} do
    entries = Map.new(data.entries)

    for {code, prefectures} <- [{"4980000", ~w(23 24)}, {"6180000", ~w(26 27)}, {"8710000", ~w(40 44)}] do
      assert entries[code] |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> Enum.sort() == prefectures
    end
  end

  test "building floors are positive integers or nil", %{rows: rows} do
    floors = for {_, {:building, _, _, _, _, _, _, floor, _, _}} <- rows, do: floor
    assert floors != []
    assert Enum.all?(floors, &(is_nil(&1) or (is_integer(&1) and &1 > 0)))
  end

  test "the data version is a date", %{data: data} do
    assert %Date{} = data.data_version
  end
end
