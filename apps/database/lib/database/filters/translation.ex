defmodule Database.Filters.Translation do
  @moduledoc """
  Filters for Translation context
  """

  import Filtrex.Type.Config

  # create configuration for transforming / validating parameters
  def categories do
    defconfig do
      text([
        :type,
        :original,
        :category,
        :program_type
      ])
    end
  end

  def leagues do
    defconfig do
      text([
        :type,
        :original,
        :real_name,
        :sports_type
      ])
    end
  end

  def countries do
    defconfig do
      text([
        :type,
        :original,
        :iso_code
      ])
    end
  end

  def teams do
    defconfig do
      text([
        :type,
        :original,
        :sports_type,
        :name
      ])
    end
  end
end
