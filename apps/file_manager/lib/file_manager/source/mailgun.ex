defmodule FileManager.Source.Mailgun do
  @moduledoc """
  Mailgun specific email handling
  """

  alias Shared.Zip
  alias FileManager.Source.TrackingUrl
  alias Shared.HttpClient

  @sites %{
    "mediafire.com" => FileManager.Source.Mediafire,
    "gallery.mailchimp.com" => FileManager.Source.Mailchimp,
    "mcusercontent.com" => FileManager.Source.Mailchimp,
    "tracking.news.trace.tv" => FileManager.Source.Mailchimp
  }

  # Update this when new tracking urls are found
  @tracking_urls ~r/\.list-manage\.com\/track\/click/i

  @doc """
  Received an email, run it through checks and rules.
  """
  def process(%{
        "Subject" => subject,
        "Sender" => from_email,
        "attachments" => attachments,
        "body-plain" => body
      }),
      do: {:ok, process_email(from_email, subject, attachments, body)}

  def process(%{
        "Subject" => subject,
        "From" => from_email,
        "attachments" => attachments,
        "body-plain" => body
      }),
      do: {:ok, process_email(from_email, subject, attachments, body)}

  def process(_), do: {:ok, "no attachments"}

  @doc """
  Fetches an email from mailgun
  """
  def get_email(message_url) do
    message_url
    |> mailgun_call()
  end

  # Process an email
  defp process_email(from_email, subject, attachments, body) do
    # Parse json array
    attachments =
      attachments
      |> decode_attachments()

    # Email rules
    rules =
      Database.Importer.get_all_email_rules()
      |> sort_rules(from_email, subject)

    # If no attachment send a single query to matcher
    # Otherwise, loop.
    attachments
    |> process_attachments(from_email, subject, rules)
    |> Enum.concat(match!(rules, from_email, subject, nil, body))
    |> fetch!(rules)
  end

  defp decode_attachments(list) when is_list(list), do: list

  defp decode_attachments(body) when is_bitstring(body) do
    case Jsonrs.decode(body) do
      {:ok, decoded} -> decoded
      _ -> []
    end
  end

  # Does it match a channel we have configured?
  # Move this to the config file?
  defp match!(rules, _from_email, _subject, nil, body) do
    # Match by body
    files =
      body
      |> grab_urls()

    cond do
      is_list(files) ->
        files
        |> List.flatten()
        |> Enum.map(fn file ->
          match!(rules, nil, nil, file, nil)
          |> case do
            {:ok, channel} -> {"external", file, channel}
            _ -> nil
          end
        end)

      is_map(files) ->
        match!(rules, nil, nil, files, nil)
        |> case do
          {:ok, channel} -> [{"external", files, channel}]
          _ -> nil
        end

      true ->
        []
    end
    |> Enum.reject(&is_nil/1)
    |> List.flatten()
  end

  defp match!(rules, _from_email, _subject, attachment, _body) when is_map(attachment) do
    {_tries, response} =
      Enum.flat_map_reduce(rules, nil, fn xp, _acc ->
        if cond_match?(xp.file_name, attachment["name"]) &&
             cond_match?(xp.file_extension, attachment["name"]) do
          {:halt, {:ok, xp.channels}}
        else
          {[xp], {:error, "no match"}}
        end
      end)

    response
  end

  defp match!(rules, from_email, subject, attachments, body) when is_list(attachments),
    do:
      Enum.map(attachments, fn attachment ->
        match!(rules, from_email, subject, attachment, body)
      end)

  # Sort through the rules and only return the rules that match the directory
  defp sort_rules([], _, _), do: []

  defp sort_rules([rule | rules], from_email, subject) do
    if cond_match?(rule.address, from_email) && cond_match?(rule.subject, subject) do
      [rule | sort_rules(rules, from_email, subject)]
    else
      sort_rules(rules, from_email, subject)
    end
  end

  # Fetch the file depending on type
  defp fetch!([], _rules), do: []

  defp fetch!([attachment | attachments], rules),
    do:
      [fetch!(attachment, rules) | fetch!(attachments, rules)]
      |> List.flatten()

  defp fetch!({"mailgun", attachment, channel}, rules) when is_map(attachment) do
    attachment
    |> fetch_email_attachment(channel, rules)
  end

  defp fetch!({"external", attachment, channel}, rules) when is_map(attachment) do
    attachment
    |> fetch_external_file(channel, rules)
  end

  # Fetch a file from an external url
  defp fetch_external_file(%{"name" => name, "url" => url}, channel, rules) do
    {_, file} =
      url
      |> http_get()

    if Regex.match?(~r/\.zip$/i, name) do
      unpack_zip(channel, name, file, rules)
    else
      {channel, name, file}
    end
  end

  # Fetch a file from mailgun
  defp fetch_email_attachment(
         %{
           "name" => name,
           "url" => url
         },
         channel,
         rules
       ) do
    {:ok, file} =
      url
      |> mailgun_call()

    if Regex.match?(~r/\.zip$/i, name) do
      unpack_zip(channel, name, file, rules)
    else
      {channel, name, file}
    end
  end

  defp http_get(url) do
    {:ok, jar} = CookieJar.new()

    result =
      HttpClient.init(%{cookie_jar: jar})
      |> HttpClient.get(url)

    CookieJar.stop(jar)

    result
  end

  defp mailgun_call(url) do
    mailgun_client()
    |> Tesla.get(url)
  end

  defp mailgun_client do
    mailgun_key = Application.get_env(:file_manager, :mailgun_key)

    middleware = [
      {Tesla.Middleware.Headers, [{"User-Agent", "Vind/#{Shared.version()}"}]},
      {
        Tesla.Middleware.BasicAuth,
        %{username: "api", password: mailgun_key}
      }
    ]

    Tesla.client(middleware, {Tesla.Adapter.Hackney, [recv_timeout: 30_000]})
  end

  # Return true otherwise it will fail instantly
  defp cond_match?(nil, _), do: true

  defp cond_match?(regex, value), do: regex |> Regex.match?(value)

  # If rule is tagged as grab urls then do checks to known urls
  def grab_urls(nil), do: []

  def grab_urls(body) do
    Regex.scan(
      ~r/((?:(?:https?|ftp):\/\/)?[\w\/\-?=%.&]+\.[\w\/\-?=%.&]+)/,
      body
    )
    |> List.flatten()
    |> Enum.uniq()
    |> parse_urls()
    |> Enum.reject(&is_nil/1)
  end

  defp parse_urls([]), do: []

  defp parse_urls([url | urls]) do
    [parse_url(url) | parse_urls(urls)]
  end

  defp parse_url(url) do
    # Is the url a tracking url? Then we need to grab the final url
    if is_a_tracking_url?(url) do
      url
      |> TrackingUrl.get()
      |> case do
        {:ok, %Tesla.Env{url: final_url}} ->
          final_url
          |> parse_real_url()

        _ ->
          nil
      end
    else
      url
      |> parse_real_url()
    end
  end

  defp parse_real_url(url) do
    host =
      url
      |> URI.parse()
      |> Map.get(:host, "")

    @sites
    |> Map.get((host || "") |> String.replace("www.", ""), nil)
    |> get_url(url)
  end

  defp get_url(nil, _), do: nil
  defp get_url(module, url), do: apply(module, :get, [url])

  defp is_a_tracking_url?(url), do: Regex.match?(@tracking_urls, url)

  defp process_attachments(attachments, from_email, subject, rules) do
    attachments
    |> List.flatten()
    |> Enum.map(fn attachment ->
      case match!(rules, from_email, subject, attachment, nil) do
        {:ok, channel} -> {"mailgun", attachment, channel}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp unpack_zip(_channel, name, file, rules) do
    {:ok, path} = Briefly.create(directory: true)
    write_file!(Path.join(path, name), file.body)

    # Unzip into the dir
    _ = Zip.unzip(Path.join(path, name), [{:cwd, path |> to_charlist()}])

    # Remove zip
    File.rm(Path.join(path, name))

    File.ls!(path)
    |> Enum.map(fn file ->
      match!(rules, nil, nil, %{"name" => Path.basename(file)}, nil)
      |> case do
        {:ok, channel} ->
          {channel, Path.join(path, file)}

        _ ->
          nil
      end
    end)
  end

  defp write_file!(path, content) do
    # Add file, its new
    File.open(
      path,
      [:binary, :write],
      fn io ->
        IO.binwrite(io, content)
      end
    )
  end
end
