defmodule Database.Observers.FileObserver do
  use Observable, :observer

  alias Database.Importer.File

  def handle_notify(:update, {_repo, _old, %File{} = file}) do
    file = Database.Repo.preload(file, :channel)

    _ =
      TaskBunny.Job.enqueue(Worker.Importer, %{"channel" => file.channel.xmltv_id},
        queue: "vind.importer"
      )

    :ok
  end
end
