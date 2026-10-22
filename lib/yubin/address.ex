defmodule Yubin.Address do
  @moduledoc """
  One row of Japan Post postal code data.

  `kind` tells which source the row comes from:

    * `:area` - a town in the home/area data (`KEN_ALL`)
    * `:building` - one floor of a high-rise building that has its own codes
    * `:business` - a business that has its own code (`JIGYOSYO`)

  `town` is `""` when the code covers the whole city. Kana are full-width katakana.
  `floor` is set only for `:building` rows, and is `nil` for the basement or an unknown floor.
  `business_name` and `street` are set only for `:business` rows. A business row has
  `town_kana: nil` when the area data has no single reading for its town.
  """

  @enforce_keys [:postal_code, :prefecture, :city, :town, :kind]
  defstruct [
    :postal_code,
    :prefecture,
    :city,
    :city_kana,
    :town,
    :town_kana,
    :note,
    :kind,
    :floor,
    :business_name,
    :street
  ]

  @type kind :: :area | :building | :business

  @type t :: %__MODULE__{
          postal_code: String.t(),
          prefecture: Yubin.Prefecture.t(),
          city: String.t(),
          city_kana: String.t() | nil,
          town: String.t(),
          town_kana: String.t() | nil,
          note: String.t() | nil,
          kind: kind(),
          floor: pos_integer() | nil,
          business_name: String.t() | nil,
          street: String.t() | nil
        }
end
