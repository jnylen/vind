defmodule Database.Uploader.File do
  use Trunk, versions: [:original], otp_app: Application.get_env(:database, :file_manager_otp_app)

  def storage_dir(
        %Trunk.State{scope: %{channel: %{xmltv_id: xmltv_id}, source: source}},
        _version
      ),
      do: "#{source}/#{xmltv_id}"
end
