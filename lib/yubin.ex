defmodule Yubin do
  @moduledoc """
  Japanese postal code lookup, with data bundled from Japan Post.
  """

  alias Yubin.Address
  alias Yubin.Prefecture

  # After NFKC, which maps "－" and "﹣" to "-", "‑" to "‐", "﹘" to "—" and "ｰ" to "ー".
  @hyphens ~c"-‐‒–—―⁃−ー"
  # After NFKC, which maps U+3000 and U+00A0 to " ".
  @spaces ~c" \t\n\r"

  @doc """
  Returns the addresses of a postal code.

  Accepts the input forms of `normalize/1`. `{:error, :not_found}` can mean a code newer
  than the bundled data, see `data_version/0`.
  """
  @spec lookup(term()) :: {:ok, [Address.t(), ...]} | {:error, :not_found | :invalid}
  def lookup(input) do
    with {:ok, code} <- parse(input),
         [_ | _] = rows <- Yubin.Table.rows(code) do
      postal_code = format(code)
      {:ok, Enum.map(rows, &to_address(&1, postal_code))}
    else
      {:error, :invalid} = error -> error
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Returns the postal code in the form `"NNN-NNNN"`, or `{:error, :invalid}` when the input is not one.

  The input is 7 digits with an optional hyphen after the third. Full-width characters,
  any hyphen or dash, a leading `〒` and spaces are accepted.

      iex> Yubin.normalize("〒５３０ー０００１")
      {:ok, "530-0001"}

      iex> Yubin.normalize("530-001")
      {:error, :invalid}
  """
  @spec normalize(term()) :: {:ok, String.t()} | {:error, :invalid}
  def normalize(input) do
    with {:ok, code} <- parse(input), do: {:ok, format(code)}
  end

  @doc "Returns the date of the Japan Post data bundled with this version."
  @spec data_version() :: Date.t()
  defdelegate data_version(), to: Yubin.Table

  @doc "Returns the 47 prefectures in JIS order."
  @spec prefectures() :: [Prefecture.t()]
  defdelegate prefectures(), to: Prefecture, as: :all

  @spec parse(term()) :: {:ok, String.t()} | {:error, :invalid}
  defp parse(input) when is_binary(input) do
    case :unicode.characters_to_nfkc_binary(input) do
      nfkc when is_binary(nfkc) ->
        case compact(nfkc, "") do
          "〒" <> code -> digits(code)
          code -> digits(code)
        end

      _invalid_utf8 ->
        {:error, :invalid}
    end
  end

  defp parse(_input), do: {:error, :invalid}

  @spec compact(String.t(), String.t()) :: String.t()
  defp compact(<<c::utf8, rest::binary>>, acc) when c in @spaces, do: compact(rest, acc)
  defp compact(<<c::utf8, rest::binary>>, acc) when c in @hyphens, do: compact(rest, <<acc::binary, ?->>)
  defp compact(<<c::utf8, rest::binary>>, acc), do: compact(rest, <<acc::binary, c::utf8>>)
  defp compact(<<>>, acc), do: acc

  @spec digits(String.t()) :: {:ok, String.t()} | {:error, :invalid}
  defp digits(<<area::binary-size(3), ?-, number::binary-size(4)>>), do: digits(area <> number)

  defp digits(<<_::binary-size(7)>> = code) do
    if digits?(code), do: {:ok, code}, else: {:error, :invalid}
  end

  defp digits(_input), do: {:error, :invalid}

  @spec digits?(binary()) :: boolean()
  defp digits?(<<c, rest::binary>>) when c in ?0..?9, do: digits?(rest)
  defp digits?(<<>>), do: true
  defp digits?(_), do: false

  @spec format(String.t()) :: String.t()
  defp format(<<area::binary-size(3), number::binary-size(4)>>), do: area <> "-" <> number

  @spec to_address(Yubin.Table.row(), String.t()) :: Address.t()
  defp to_address(row, postal_code) do
    {kind, pref_code, city, city_kana, town, town_kana, note, floor, business_name, street} = row

    %Address{
      postal_code: postal_code,
      prefecture: Prefecture.from_code(pref_code),
      city: city,
      city_kana: city_kana,
      town: town,
      town_kana: town_kana,
      note: note,
      kind: kind,
      floor: floor,
      business_name: business_name,
      street: street
    }
  end
end
