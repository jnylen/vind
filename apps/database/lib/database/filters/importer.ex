defmodule Database.Filters.Importer do
  @moduledoc """
  Filters for Importer context
  """

  import Filtrex.Type.Config

  def airings do
    defconfig do
      text([
        :start_time
      ])
    end
  end

  def batches do
    defconfig do
      text([
        :name,
        :status,
        :channel_id
      ])
    end
  end
  def channels do
    defconfig do
      text([
        :name
      ])
    end
  end

  def files do
    defconfig do
      text([
        :file_name,
        :status,
        :channel_id
      ])
    end
  end

  def jobs do
    defconfig do
      text([
        :type,
        :name
      ])
    end
  end

  def email_rules do
    defconfig do
      text([
        :channel_id,
        :address,
        :file_name,
        :file_extension,
        :subject
      ])
    end
  end

  def ftp_rules do
    defconfig do
      text([
        :channel_id,
        :directory,
        :file_name,
        :file_extension
      ])
    end
  end

  def augmenter_rules do
    defconfig do
      text([
        :augmenter,
        :title,
        :title_language,
        :channel_id,
        :otherfield,
        :othervalue,
        :remoteref,
        :matchby
      ])
    end
  end
end
