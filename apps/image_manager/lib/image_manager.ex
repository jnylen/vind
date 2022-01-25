defmodule ImageManager do
  @moduledoc """
  Documentation for ImageManager.
  """

  alias Database.Image.File, as: ImageFile
  alias Database.Repo
  alias ImageManager.{Image, Uploader}
  alias Shared.HttpClient

  def add_file?([]), do: []
  def add_file?([_file | _files]), do: []

  def add_file?(%Image{} = image) do
    if added_file?(image) do
      {:error, "already added"}
    else
      image
      |> check_file!()
      |> upload_file!()
    end
  end

  def add_file?(_), do: nil

  def add_or_get_file?(%Image{source: source} = image) do
    source
    |> Database.Image.find_image_by_source!()
    |> case do
      nil ->
        image
        |> check_file!()
        |> upload_file!()
        |> case do
          {:ok, res} -> res
          {:error, _} -> nil
          res -> res
        end

      val ->
        val
    end
  end

  def check_file!(%Image{} = image) do
    image
    |> determine_file!()
    |> case do
      {:error, _} -> false
      {:ok, "svg"} -> image
      {:ok, new_image} -> new_image
    end
  end

  def upload_file!(false), do: {:error, "check_file!/1 failed."}

  def upload_file!(%Image{} = image) do
    record_changeset = ImageFile.changeset(%ImageFile{}, image |> Map.delete(:__struct__))
    {:ok, file} = image |> get_file!()

    record_changeset
    |> Database.Repo.insert()
    |> case do
      {:ok, record} ->
        file_name =
          "#{record.id}/original#{ImageManager.Uploader.Helper.file_extension(image.file_type)}"

        # Uploader
        ExAws.S3.put_object(
          Application.get_env(:image_manager, :bucket_name, "vind-images"),
          file_name,
          File.read!(file),
          [
            {:content_type, ImageManager.Uploader.Helper.content_type(image.file_type)},
            {:acl, :public_read}
          ]
        )
        |> ExAws.request()
        |> case do
          {:ok, _} ->
            record
            |> ImageFile.changeset(%{uploaded: true, file_name: file_name})
            |> Database.Repo.update()

          error ->
            error
        end

      error ->
        error
    end
  end

  defp added_file?(%Image{source: source} = image) do
    source
    |> Database.Image.find_image_by_source!()
    |> case do
      nil -> false
      _ -> true
    end
  end

  defp determine_file!(%Image{file_type: "svg"}), do: {:ok, "svg"}

  defp determine_file!(%Image{source: source} = image) do
    source
    |> Fastimage.info()
    |> case do
      {:ok, fast_img} ->
        new_image =
          image
          |> Map.put(:width, fast_img.dimensions.width)
          |> Map.put(:height, fast_img.dimensions.height)
          |> Map.put(:file_type, fast_img.image_type |> to_string())
          |> Map.put(:source, fast_img.source)
          |> Map.put(:source_type, fast_img.source_type |> to_string())

        {:ok, new_image}

      _ ->
        {:error, "didn't return the right format"}
    end
  rescue
    _ -> {:error, "didn't return the right format"}
  end

  def calculate_size(%{file_type: "svg"}), do: "svg"

  def calculate_size(%{height: height, width: width}) when width > height,
    do: "landscape"

  def calculate_size(%{height: height, width: width}) when width < height,
    do: "portrait"

  def calculate_size(%{height: height, width: width}) when width == height,
    do: "square"

  defp uploader_class(%{file_type: "svg"}), do: ImageManager.Uploader.SVG

  defp uploader_class(%{height: height, width: width}) when width > height,
    do: ImageManager.Uploader.Landscape

  defp uploader_class(%{height: height, width: width}) when width < height,
    do: ImageManager.Uploader.Portrait

  defp get_file!(%Image{source: url}) do
    {:ok, path} = Briefly.create()

    HttpClient.init()
    |> HttpClient.get(url)
    |> case do
      {_, %{body: body}} ->
        File.write!(path, body)

        {:ok, path}

      _ ->
        {:error, "no body"}
    end
  end

  def url_for(%Database.Image.File{file_name: file_name} = image) do
    "https://vindimg.b-cdn.net/" <> file_name
  end
end
