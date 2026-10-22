defmodule Yubin.BuildTest do
  use ExUnit.Case, async: true

  # Each line is copied verbatim from utf_ken_all.csv or JIGYOSYO.CSV (2026-09-30).

  defp row(line) do
    [{code, row}] = Yubin.Build.ken_all(line <> "\n")
    to_map(code, row)
  end

  defp to_map(code, row) do
    {kind, pref, city, city_kana, town, town_kana, note, floor, name, street} = row

    %{
      code: code,
      kind: kind,
      prefecture: pref,
      city: city,
      city_kana: city_kana,
      town: town,
      town_kana: town_kana,
      note: note,
      floor: floor,
      business_name: name,
      street: street
    }
  end

  describe "rule 1: 以下に掲載がない場合" do
    test "becomes an empty town" do
      assert %{town: "", town_kana: "", note: nil, kind: :area, city: "札幌市中央区"} =
               row(
                 ~s(01101,"060  ","0600000","ホッカイドウ","サッポロシチュウオウク","イカニケイサイガナイバアイ","北海道","札幌市中央区","以下に掲載がない場合",0,0,0,0,0,0)
               )
    end
  end

  describe "rule 2: 〇〇の次に番地がくる場合" do
    test "becomes an empty town" do
      assert %{town: "", town_kana: "", note: nil, city: "猿島郡境町"} =
               row(
                 ~s(08546,"30604","3060433","イバラキケン","サシマグンサカイマチ","サカイマチノツギニバンチガクルバアイ","茨城県","猿島郡境町","境町の次に番地がくる場合",0,0,0,0,0,0)
               )
    end
  end

  describe "rule 3: {village}一円" do
    test "becomes an empty town when the prefix is the city" do
      assert %{town: "", town_kana: "", note: nil, city: "利島村"} =
               row(~s(13362,"10003","1000301","トウキョウト","トシマムラ","トシマムライチエン","東京都","利島村","利島村一円",0,0,0,0,0,0))
    end

    test "becomes an empty town when the city name includes its 郡" do
      assert %{town: "", town_kana: ""} =
               row(
                 ~s(15586,"958  ","9580061","ニイガタケン","イワフネグンアワシマウラムラ","アワシマウラムライチエン","新潟県","岩船郡粟島浦村","粟島浦村一円",0,0,0,0,0,0)
               )
    end

    test "keeps the place named 一円 in 多賀町" do
      assert %{town: "一円", town_kana: "イチエン", note: nil, city: "犬上郡多賀町"} =
               row(~s(25443,"52203","5220317","シガケン","イヌカミグンタガチョウ","イチエン","滋賀県","犬上郡多賀町","一円",0,0,0,0,0,0))
    end
  end

  describe "rule 4: building floors" do
    test "（N階） gives the floor and keeps the building name" do
      assert %{kind: :building, floor: 1, town: "中央アエル", town_kana: "チュウオウアエル", note: nil} =
               row(
                 ~s(04101,"980  ","9806101","ミヤギケン","センダイシアオバク","チュウオウアエル（１カイ）","宮城県","仙台市青葉区","中央アエル（１階）",0,0,0,0,0,0)
               )
    end

    test "parses a two-digit floor" do
      assert %{kind: :building, floor: 10, town: "中央アエル"} =
               row(
                 ~s(04101,"980  ","9806110","ミヤギケン","センダイシアオバク","チュウオウアエル（１０カイ）","宮城県","仙台市青葉区","中央アエル（１０階）",0,0,0,0,0,0)
               )
    end

    test "（地階・階層不明） gives a nil floor" do
      assert %{kind: :building, floor: nil, town: "中央アエル", town_kana: "チュウオウアエル"} =
               row(
                 ~s(04101,"980  ","9806190","ミヤギケン","センダイシアオバク","チュウオウアエル（チカイ・カイソウフメイ）","宮城県","仙台市青葉区","中央アエル（地階・階層不明）",0,0,0,0,0,0)
               )
    end

    test "a second bracket before the floor goes into note" do
      assert %{
               kind: :building,
               floor: 1,
               town: "名駅ミッドランドスクエア",
               town_kana: "メイエキミッドランドスクエア",
               note: "高層棟"
             } =
               row(
                 ~s(23105,"450  ","4506201","アイチケン","ナゴヤシナカムラク","メイエキミッドランドスクエア（コウソウトウ）（１カイ）","愛知県","名古屋市中村区","名駅ミッドランドスクエア（高層棟）（１階）",0,0,0,0,0,0)
               )
    end
  end

  describe "rule 5: other brackets" do
    test "a number range goes into note" do
      assert %{kind: :area, town: "草刈", town_kana: "クサカリ", note: "１６５６〜１９９９"} =
               row(~s(12219,"29001","2900156","チバケン","イチハラシ","クサカリ（１６５６−１９９９）","千葉県","市原市","草刈（１６５６〜１９９９）",1,0,0,0,0,0))
    end

    test "a sub-area goes into note" do
      assert %{town: "美田", town_kana: "ミタ", note: "夕張"} =
               row(~s(01459,"07102","0710221","ホッカイドウ","カミカワグンビエイチョウ","ミタ（ユウバリ）","北海道","上川郡美瑛町","美田（夕張）",1,0,0,0,0,0))
    end

    test "Kyoto street directions go into note, and the kana has no bracket" do
      assert %{
               town: "大黒町",
               town_kana: "ダイコクチョウ",
               note: "釜座通夷川下る、釜座通二条上る、夷川通釜座東入、夷川通釜座西入"
             } =
               row(
                 ~s(26104,"604  ","6040014","キョウトフ","キョウトシナカギョウク","ダイコクチョウ","京都府","京都市中京区","大黒町（釜座通夷川下る、釜座通二条上る、夷川通釜座東入、夷川通釜座西入）",0,0,0,0,0,0)
               )
    end

    test "a block list goes into note" do
      assert %{town: "萩原台西", town_kana: "ハギハラダイニシ", note: "１、２丁目、３丁目１番〜２８２番"} =
               row(
                 ~s(28217,"666  ","6660006","ヒョウゴケン","カワニシシ","ハギハラダイニシ（１、２チョウメ、３チョウメ１バン−２８２バン）","兵庫県","川西市","萩原台西（１、２丁目、３丁目１番〜２８２番）",1,0,1,0,0,0)
               )
    end
  end

  describe "rule 6: other values" do
    test "stay as Japan Post writes them" do
      assert %{
               code: "0640941",
               kind: :area,
               prefecture: "01",
               city: "札幌市中央区",
               city_kana: "サッポロシチュウオウク",
               town: "旭ケ丘",
               town_kana: "アサヒガオカ",
               note: nil,
               floor: nil
             } =
               row(~s(01101,"064  ","0640941","ホッカイドウ","サッポロシチュウオウク","アサヒガオカ","北海道","札幌市中央区","旭ケ丘",0,0,1,0,0,0))
    end

    test "keep full-width digits" do
      assert %{town: "秋月１条", town_kana: "アキツキ１ジョウ"} =
               row(~s(01204,"079  ","0798401","ホッカイドウ","アサヒカワシ","アキツキ１ジョウ","北海道","旭川市","秋月１条",0,0,1,0,0,0))

      assert %{town: "中央ＳＳ３０住友生命仙台中央ビル"} =
               row(
                 ~s(04101,"980  ","9806090","ミヤギケン","センダイシアオバク","チュウオウＳＳ３０スミトモセイメイセンダイチュウオウビル（チカイ・カイソウフメイ）","宮城県","仙台市青葉区","中央ＳＳ３０住友生命仙台中央ビル（地階・階層不明）",0,0,0,0,0,0)
               )
    end
  end

  describe "jigyosyo/2" do
    test "keeps the business values and takes the kana from the area rows" do
      ken_all =
        Yubin.Build.ken_all("""
        01101,"060  ","0600001","ホッカイドウ","サッポロシチュウオウク","キタ１ジョウニシ（１−１９チョウメ）","北海道","札幌市中央区","北一条西（１〜１９丁目）",1,0,1,0,0,0
        01101,"064  ","0640821","ホッカイドウ","サッポロシチュウオウク","キタ１ジョウニシ（２０−２８チョウメ）","北海道","札幌市中央区","北一条西（２０〜２８丁目）",1,0,1,0,0,0
        """)

      [{code, row}] =
        Yubin.Build.jigyosyo(
          ~s(01101,"\(ｶﾌﾞ\) ﾆﾎﾝｹｲｻﾞｲｼﾝﾌﾞﾝｼﾔ ｻﾂﾎﾟﾛｼｼﾔ","株式会社　日本経済新聞社　札幌支社","北海道","札幌市中央区","北一条西","６丁目１－２アーバンネット札幌ビル２Ｆ","0608621","060  ","札幌中央",0,0,0\r\n),
          ken_all
        )

      assert %{
               code: "0608621",
               kind: :business,
               prefecture: "01",
               city: "札幌市中央区",
               city_kana: "サッポロシチュウオウク",
               town: "北一条西",
               town_kana: "キタ１ジョウニシ",
               note: nil,
               floor: nil,
               business_name: "株式会社　日本経済新聞社　札幌支社",
               street: "６丁目１－２アーバンネット札幌ビル２Ｆ"
             } = to_map(code, row)
    end

    test "leaves the kana nil when no area row matches" do
      [{_code, row}] =
        Yubin.Build.jigyosyo(
          ~s(01101,"ｲﾄｳｸﾞﾐﾄﾞｹﾝ ｶﾌﾞｼｷｶﾞｲｼﾔ","伊藤組土建　（株）","北海道","札幌市中央区","北四条西","４丁目１番地","0608554","060  ","札幌中央",0,0,0\r\n),
          []
        )

      assert %{city_kana: nil, town_kana: nil, business_name: "伊藤組土建　（株）"} = to_map("", row)
    end
  end

  describe "pack/1" do
    test "Yubin.Table decodes every row as it was packed" do
      entries = [
        {"0010000", [{:area, "01", "札幌市北区", "サッポロシキタク", "", "", nil, nil, nil, nil}]},
        {"1830000", [{:area, "13", "府中市", "フチュウシ", "町", "マチ", String.duplicate("番", 300), nil, nil, nil}]},
        {"7260000", [{:area, "34", "府中市", "フチュウシ", "町", "マチ", "", nil, nil, nil}]},
        {"9806101",
         [
           {:building, "04", "仙台市青葉区", "センダイシアオバク", "中央アエル", "チュウオウアエル", nil, 1, nil, nil},
           {:building, "04", "仙台市青葉区", "センダイシアオバク", "中央アエル", "チュウオウアエル", "高層棟", nil, nil, nil}
         ]},
        {"9999999", [{:business, "47", "那覇市", nil, "泉崎", nil, nil, nil, "沖縄県庁", "１丁目２－２"}]}
      ]

      packed = Yubin.Build.pack(entries)

      for {code, rows} <- entries do
        assert Yubin.Table.rows(code, packed) == rows
      end

      assert Yubin.Table.rows("0000000", packed) == []
      assert Yubin.Table.rows("5000000", packed) == []
    end
  end

  describe "row counts" do
    test "raise when a quoted newline merges two lines into one row" do
      csv =
        ~s(01101,"064  ","0640941","ホッカイドウ","サッポロシチュウオウク","アサヒガオカ","北海道","札幌市中央区","旭ケ\n丘",0,0,1,0,0,0\n)

      assert_raise RuntimeError, ~r/2 lines, but 1 rows parsed/, fn -> Yubin.Build.ken_all(csv) end
    end

    test "raise when the prefecture does not match the local government code" do
      csv =
        ~s(02101,"064  ","0640941","ホッカイドウ","サッポロシチュウオウク","アサヒガオカ","北海道","札幌市中央区","旭ケ丘",0,0,1,0,0,0\n)

      assert_raise RuntimeError, ~r/02101 does not belong to 北海道/, fn -> Yubin.Build.ken_all(csv) end
    end
  end
end
