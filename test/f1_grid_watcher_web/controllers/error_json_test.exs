defmodule F1GridWatcherWeb.ErrorJSONTest do
  use F1GridWatcherWeb.ConnCase, async: true

  test "renders 404" do
    assert F1GridWatcherWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert F1GridWatcherWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
