# Yubin

[![CI](https://github.com/NexPB/yubin/actions/workflows/test.yml/badge.svg)](https://github.com/NexPB/yubin/actions/workflows/test.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/yubin.svg)](https://hex.pm/packages/yubin)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/yubin)

Japanese postal code (郵便番号) lookup, with data bundled from Japan Post.

## Installation

Add `yubin` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:yubin, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
iex> Yubin.lookup("〒１００ー０００１")
{:ok,
 [
   %Yubin.Address{
     postal_code: "100-0001",
     prefecture: %Yubin.Prefecture{code: "13", slug: :tokyo, name: "東京都", kana: "トウキョウト"},
     city: "千代田区",
     city_kana: "チヨダク",
     town: "千代田",
     town_kana: "チヨダ",
     kind: :area,
     ...
   }
 ]}

iex> Yubin.normalize("1000001")
{:ok, "100-0001"}

iex> Yubin.lookup("000-0000")
{:error, :not_found}
```

See the [documentation](https://hexdocs.pm/yubin) for the full API.

## Data

The data comes from Japan Post's
[postal code data](https://www.post.japanpost.jp/zipcode/download.html)
(`utf_ken_all.zip` and `jigyosyo.zip`). Japan Post claims no copyright on it:
"郵便番号データに限っては日本郵便株式会社は著作権を主張しません。自由に配布していただいて結構です。"

`Yubin.data_version/0` returns the date of the bundled data. Each node loads the data
into `:persistent_term` at start, which uses about 8 MiB of memory.

To rebuild `priv/postal.etf` from the latest files (needs `iconv`):

```shell
mix yubin.build
```

## License

Copyright (c) 2026 Lorenzo

Released under the MIT License. See [LICENSE](https://github.com/NexPB/yubin/blob/main/LICENSE).
