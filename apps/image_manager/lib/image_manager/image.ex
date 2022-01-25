defmodule ImageManager.Image do
  defstruct source: nil,
            source_type: nil,
            file_type: nil,
            width: nil,
            height: nil,
            type: nil,
            copyright: nil,
            author: [],
            language: nil,
            hash: nil
end
