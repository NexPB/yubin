defmodule YubinTest do
  use ExUnit.Case, async: true

  doctest Yubin

  describe "normalize/1" do
    test "accepts ASCII digits with and without a hyphen" do
      assert Yubin.normalize("530-0001") == {:ok, "530-0001"}
      assert Yubin.normalize("5300001") == {:ok, "530-0001"}
    end

    test "accepts full-width digits" do
      assert Yubin.normalize("５３００００１") == {:ok, "530-0001"}
      assert Yubin.normalize("５３０-0001") == {:ok, "530-0001"}
      assert Yubin.normalize("５３０－０００１") == {:ok, "530-0001"}
    end

    test "accepts every hyphen kind" do
      for hyphen <- ~w(- ‐ ‑ ‒ – — ― ⁃ − ー ｰ － ﹣ ﹘) do
        assert Yubin.normalize("530#{hyphen}0001") == {:ok, "530-0001"}, inspect(hyphen)
      end
    end

    test "accepts a 〒 prefix" do
      assert Yubin.normalize("〒530-0001") == {:ok, "530-0001"}
      assert Yubin.normalize("〒5300001") == {:ok, "530-0001"}
      assert Yubin.normalize("〒 530-0001") == {:ok, "530-0001"}
      assert Yubin.normalize("〶530-0001") == {:ok, "530-0001"}
    end

    test "accepts leading, trailing and inner spaces" do
      for input <- [" 530-0001", "530-0001 ", "530 - 0001", "530 0001", "\t530-0001\n", "　〒　５３０　０００１　"] do
        assert Yubin.normalize(input) == {:ok, "530-0001"}, inspect(input)
      end
    end

    test "rejects anything else" do
      for input <- [
            "",
            " ",
            "〒",
            "530-001",
            "530000",
            "５３０００１",
            "53000011",
            "530-00011",
            "530--0001",
            "530-00-01",
            "5300-001",
            "53-00001",
            "530-000a",
            "abc-defg",
            "0001〒530",
            "530_0001",
            <<0xFF, 0xFE>>
          ] do
        assert Yubin.normalize(input) == {:error, :invalid}, inspect(input)
      end
    end

    test "rejects non-strings" do
      for input <- [nil, 5_300_001, ~c"5300001", :"530-0001"] do
        assert Yubin.normalize(input) == {:error, :invalid}
      end
    end
  end

  describe "lookup/1" do
    test "returns the one address of a code" do
      assert {:ok, [address]} = Yubin.lookup("５３０-０００１")

      assert %Yubin.Address{
               postal_code: "530-0001",
               prefecture: %Yubin.Prefecture{code: "27", slug: :osaka},
               city: "大阪市北区",
               city_kana: "オオサカシキタク",
               town: "梅田",
               town_kana: "ウメダ",
               kind: :area,
               floor: nil
             } = address
    end

    test "returns every address of a code" do
      assert {:ok, addresses} = Yubin.lookup("4520961")
      assert length(addresses) == 66
      assert Enum.all?(addresses, &match?(%{postal_code: "452-0961", city: "清須市", kind: :area}, &1))
      assert addresses |> Enum.map(& &1.town) |> Enum.uniq() |> length() == 66
    end

    test "returns the floor of a building" do
      assert {:ok, [%Yubin.Address{kind: :building, floor: 1, town: "中央アエル"}]} = Yubin.lookup("980-6101")
    end

    test "returns a business" do
      assert {:ok, [address]} = Yubin.lookup("0608621")

      assert %Yubin.Address{
               kind: :business,
               prefecture: %Yubin.Prefecture{slug: :hokkaido},
               city: "札幌市中央区",
               town: "北一条西",
               business_name: "株式会社　日本経済新聞社　札幌支社",
               street: "６丁目１－２アーバンネット札幌ビル２Ｆ"
             } = address
    end

    test "returns both prefectures of a code that covers two" do
      for {code, slugs} <- [{"4980000", [:aichi, :mie]}, {"6180000", [:kyoto, :osaka]}, {"8710000", [:fukuoka, :oita]}] do
        assert {:ok, addresses} = Yubin.lookup(code)
        assert addresses |> Enum.map(& &1.prefecture.slug) |> Enum.uniq() |> Enum.sort() == slugs
      end
    end

    test "returns :not_found for a valid code that has no address" do
      assert Yubin.lookup("000-0000") == {:error, :not_found}
    end

    test "returns :invalid for input that is not a code" do
      for input <- ["", "530-001", "530--0001", "abcdefg", nil] do
        assert Yubin.lookup(input) == {:error, :invalid}
      end
    end
  end

  test "data_version/0 returns the date of the data" do
    assert %Date{} = Yubin.data_version()
  end

  test "prefectures/0 returns the 47 prefectures in JIS order" do
    prefectures = Yubin.prefectures()

    assert length(prefectures) == 47

    assert Enum.map(prefectures, & &1.code) ==
             Enum.map(1..47, &(&1 |> Integer.to_string() |> String.pad_leading(2, "0")))

    assert %Yubin.Prefecture{code: "01", slug: :hokkaido, name: "北海道"} = List.first(prefectures)
    assert %Yubin.Prefecture{code: "13", slug: :tokyo, name: "東京都"} = Enum.at(prefectures, 12)
    assert %Yubin.Prefecture{code: "47", slug: :okinawa, name: "沖縄県"} = List.last(prefectures)
    assert prefectures |> Enum.map(& &1.slug) |> Enum.uniq() |> length() == 47
  end
end
