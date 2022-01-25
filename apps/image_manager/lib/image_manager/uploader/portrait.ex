defmodule ImageManager.Uploader.Portrait do
  use Trunk, versions: [:original], otp_app: :image_manager

  alias ImageManager.Uploader.Helper

  def storage_opts(_state, _version), do: [acl: :public_read]

  def storage_dir(%Trunk.State{scope: %{id: model_id}}, _version),
    do: "#{model_id}"

  def filename(
        %{scope: %{file_type: file_type}} = _,
        version
      ),
      do: "#{version}#{Helper.file_extension(file_type)}"
end
