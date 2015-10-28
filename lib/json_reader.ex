defmodule JsonReader do
  def parse(json_string) do
    Poison.Parser.parse!(json_string)
  end

  def stations(json) do
    parse(json)["marker"]
    |> Enum.map(&marker_to_station(&1))
  end

  defp marker_to_station(json_blob) do
    hal = json_blob["hal2option"]
    %Station{
      id:    clean_id(hal["tooltip"]),
      name:  clean_name(hal["tooltip"]),
      lat:   String.to_float(json_blob["lat"]),
      lng:   String.to_float(json_blob["lng"]),
      bikes: clean_bikes(hal["bikes"]),
    }
  end

  defp clean_id(tooltip) do
    tooltip
    |> String.split("&", parts: 2)
    |> hd
    |> String.strip(?')
    |> String.to_integer
  end

  defp clean_name(tooltip) do
    tooltip
    |> String.split(";", parts: 2)
    |> List.last
    |> String.strip(?')
    |> String.replace("&nbsp;", " ")
  end

  defp clean_bikes(bikes) do
    bikes
    |> String.split(",", trim: true)
    |> Enum.map(&String.to_integer(&1))
  end
end
