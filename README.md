# Yubin

Japanese postal code lookup, with data bundled from Japan Post.

## Data

The data comes from Japan Post's
[postal code data](https://www.post.japanpost.jp/zipcode/download.html)
(`utf_ken_all.zip` and `jigyosyo.zip`). Japan Post claims no copyright on it:
"郵便番号データに限っては日本郵便株式会社は著作権を主張しません。自由に配布していただいて結構です。"

Each node loads the data into `:persistent_term` at start, which uses about 8 MiB of memory.

To rebuild `priv/postal.etf` from the latest files (needs `iconv`):

    mix yubin.build

## License

MIT
