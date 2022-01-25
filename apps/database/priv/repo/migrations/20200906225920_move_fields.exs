defmodule Database.Repo.Migrations.MoveFields do
  use Ecto.Migration

  alias Database.Repo

  def change do
    migrate_ftp()
    migrate_email()

    alter table("email_rules") do
      remove(:channel_id, references("channels", type: :uuid))
    end

    alter table("ftp_rules") do
      remove(:channel_id, references("channels", type: :uuid))
    end
  end

  defp migrate_ftp() do
    Database.Importer.FtpRule
    |> Repo.all()
    |> Repo.preload(:channels)
    |> Enum.map(fn rule ->
      rule
      |> Database.Importer.update_ftp_rule(%{
        "channels" => [rule.channel_id]
      })
    end)
  end

  defp migrate_email() do
    Database.Importer.EmailRule
    |> Repo.all()
    |> Repo.preload(:channels)
    |> Enum.map(fn rule ->
      rule
      |> Database.Importer.update_email_rule(%{
        "channels" => [rule.channel_id]
      })
    end)
  end
end
