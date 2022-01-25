defmodule ImageManager.Uploader.SVG do
  use Trunk, versions: [:original, :png], otp_app: :image_manager

  def transform(%Trunk.State{}, :png),
    do: {:convert, "-strip -thumbnail 200x200>"}

  def storage_opts(_state, _version), do: [acl: :public_read]

  def storage_dir(_, _version),
    do: ""

  def filename(%{rootname: _rootname, extname: extname, scope: %{id: model_id}}, _version),
    do: "#{model_id}#{extname}"
end
