defmodule Mix.Tasks.Yubin.Build do
  @shortdoc "Downloads the Japan Post data and writes priv/postal.etf"

  @moduledoc """
  Downloads the Japan Post postal code files and writes `priv/postal.etf`.

      $ mix yubin.build

  The data version is the most recent `Last-Modified` date of the two files, in JST.
  Decoding `JIGYOSYO.CSV` (Shift_JIS) needs the `iconv` command.
  """

  use Mix.Task

  @ken_all_url "https://www.post.japanpost.jp/service/search/zipcode/download/utf/zip/utf_ken_all.zip"
  @jigyosyo_url "https://www.post.japanpost.jp/service/search/zipcode/download/office/zip/jigyosyo.zip"
  @output "priv/postal.etf"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("compile")
    {:ok, _} = Application.ensure_all_started(:req)

    {ken_all_csv, ken_all_date} = download!(@ken_all_url, "utf_ken_all.csv")
    {jigyosyo_csv, jigyosyo_date} = download!(@jigyosyo_url, "JIGYOSYO.CSV")
    data_version = Enum.max([ken_all_date, jigyosyo_date], Date)

    ken_all = Yubin.Build.ken_all(ken_all_csv)
    jigyosyo = jigyosyo_csv |> cp932_to_utf8!() |> Yubin.Build.jigyosyo(ken_all)

    File.mkdir_p!(Path.dirname(@output))
    File.write!(@output, Yubin.Build.encode(ken_all, jigyosyo, data_version))

    Mix.shell().info("""
    Wrote #{@output} (#{div(File.stat!(@output).size, 1024)} KiB)
      data version: #{data_version}
      utf_ken_all.csv: #{length(ken_all)} rows
      JIGYOSYO.CSV: #{length(jigyosyo)} rows
    """)
  end

  defp download!(url, name) do
    Mix.shell().info("Downloading #{url}")
    resp = Req.get!(url, decoders: [:zip], http_errors: :raise)

    files = Map.new(resp.body, fn {path, content} -> {Path.basename(to_string(path)), content} end)

    case files do
      %{^name => content} -> {content, last_modified!(resp, url)}
      _ -> Mix.raise("#{name} not found in #{url}, which has #{inspect(Map.keys(files))}")
    end
  end

  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec) |> Enum.with_index(1) |> Map.new()

  # RFC 9110 IMF-fixdate, e.g. "Wed, 30 Sep 2026 07:46:52 GMT".
  defp last_modified!(resp, url) do
    with [value] <- Req.Response.get_header(resp, "last-modified"),
         [_weekday, d, mon, y, time, "GMT"] <- String.split(value),
         {day, ""} <- Integer.parse(d),
         {:ok, month} <- Map.fetch(@months, mon),
         {year, ""} <- Integer.parse(y),
         {:ok, date} <- Date.new(year, month, day),
         {:ok, time} <- Time.from_iso8601(time),
         {:ok, utc} <- NaiveDateTime.new(date, time) do
      utc |> NaiveDateTime.add(9, :hour) |> NaiveDateTime.to_date()
    else
      _ -> Mix.raise("#{url} has no valid Last-Modified header")
    end
  end

  defp cp932_to_utf8!(content) do
    path = Path.join(System.tmp_dir!(), "yubin-jigyosyo-#{System.unique_integer([:positive])}.csv")
    File.write!(path, content)

    try do
      case System.cmd("iconv", ["-f", "CP932", "-t", "UTF-8", path]) do
        {utf8, 0} -> utf8
        {_, status} -> Mix.raise("iconv exited with status #{status}")
      end
    after
      File.rm(path)
    end
  end
end
