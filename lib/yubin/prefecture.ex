defmodule Yubin.Prefecture do
  @moduledoc """
  One of the 47 prefectures, identified by its JIS X 0401 code.

  `slug` is a stable romaji atom, suitable for an `Ecto.Enum`.
  """

  @enforce_keys [:code, :slug, :name, :kana]
  defstruct [:code, :slug, :name, :kana]

  @type slug ::
          :hokkaido
          | :aomori
          | :iwate
          | :miyagi
          | :akita
          | :yamagata
          | :fukushima
          | :ibaraki
          | :tochigi
          | :gunma
          | :saitama
          | :chiba
          | :tokyo
          | :kanagawa
          | :niigata
          | :toyama
          | :ishikawa
          | :fukui
          | :yamanashi
          | :nagano
          | :gifu
          | :shizuoka
          | :aichi
          | :mie
          | :shiga
          | :kyoto
          | :osaka
          | :hyogo
          | :nara
          | :wakayama
          | :tottori
          | :shimane
          | :okayama
          | :hiroshima
          | :yamaguchi
          | :tokushima
          | :kagawa
          | :ehime
          | :kochi
          | :fukuoka
          | :saga
          | :nagasaki
          | :kumamoto
          | :oita
          | :miyazaki
          | :kagoshima
          | :okinawa

  @type t :: %__MODULE__{code: String.t(), slug: slug(), name: String.t(), kana: String.t()}

  @prefectures [
    {"01", :hokkaido, "北海道", "ホッカイドウ"},
    {"02", :aomori, "青森県", "アオモリケン"},
    {"03", :iwate, "岩手県", "イワテケン"},
    {"04", :miyagi, "宮城県", "ミヤギケン"},
    {"05", :akita, "秋田県", "アキタケン"},
    {"06", :yamagata, "山形県", "ヤマガタケン"},
    {"07", :fukushima, "福島県", "フクシマケン"},
    {"08", :ibaraki, "茨城県", "イバラキケン"},
    {"09", :tochigi, "栃木県", "トチギケン"},
    {"10", :gunma, "群馬県", "グンマケン"},
    {"11", :saitama, "埼玉県", "サイタマケン"},
    {"12", :chiba, "千葉県", "チバケン"},
    {"13", :tokyo, "東京都", "トウキョウト"},
    {"14", :kanagawa, "神奈川県", "カナガワケン"},
    {"15", :niigata, "新潟県", "ニイガタケン"},
    {"16", :toyama, "富山県", "トヤマケン"},
    {"17", :ishikawa, "石川県", "イシカワケン"},
    {"18", :fukui, "福井県", "フクイケン"},
    {"19", :yamanashi, "山梨県", "ヤマナシケン"},
    {"20", :nagano, "長野県", "ナガノケン"},
    {"21", :gifu, "岐阜県", "ギフケン"},
    {"22", :shizuoka, "静岡県", "シズオカケン"},
    {"23", :aichi, "愛知県", "アイチケン"},
    {"24", :mie, "三重県", "ミエケン"},
    {"25", :shiga, "滋賀県", "シガケン"},
    {"26", :kyoto, "京都府", "キョウトフ"},
    {"27", :osaka, "大阪府", "オオサカフ"},
    {"28", :hyogo, "兵庫県", "ヒョウゴケン"},
    {"29", :nara, "奈良県", "ナラケン"},
    {"30", :wakayama, "和歌山県", "ワカヤマケン"},
    {"31", :tottori, "鳥取県", "トットリケン"},
    {"32", :shimane, "島根県", "シマネケン"},
    {"33", :okayama, "岡山県", "オカヤマケン"},
    {"34", :hiroshima, "広島県", "ヒロシマケン"},
    {"35", :yamaguchi, "山口県", "ヤマグチケン"},
    {"36", :tokushima, "徳島県", "トクシマケン"},
    {"37", :kagawa, "香川県", "カガワケン"},
    {"38", :ehime, "愛媛県", "エヒメケン"},
    {"39", :kochi, "高知県", "コウチケン"},
    {"40", :fukuoka, "福岡県", "フクオカケン"},
    {"41", :saga, "佐賀県", "サガケン"},
    {"42", :nagasaki, "長崎県", "ナガサキケン"},
    {"43", :kumamoto, "熊本県", "クマモトケン"},
    {"44", :oita, "大分県", "オオイタケン"},
    {"45", :miyazaki, "宮崎県", "ミヤザキケン"},
    {"46", :kagoshima, "鹿児島県", "カゴシマケン"},
    {"47", :okinawa, "沖縄県", "オキナワケン"}
  ]

  @all for {code, slug, name, kana} <- @prefectures,
           do: %{__struct__: __MODULE__, code: code, slug: slug, name: name, kana: kana}

  @doc "Returns the 47 prefectures in JIS order, from `01` Hokkaido to `47` Okinawa."
  @spec all() :: [t()]
  def all, do: @all

  @doc "Returns the prefecture with the 2-digit JIS code, or `nil`."
  @spec from_code(String.t()) :: t() | nil
  for prefecture <- @all do
    def from_code(unquote(prefecture.code)), do: unquote(Macro.escape(prefecture))
  end

  def from_code(_code), do: nil

  @doc "Returns the prefecture with the slug, or `nil`."
  @spec from_slug(atom()) :: t() | nil
  for prefecture <- @all do
    def from_slug(unquote(prefecture.slug)), do: unquote(Macro.escape(prefecture))
  end

  def from_slug(_slug), do: nil
end
