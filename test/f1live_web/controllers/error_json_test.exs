defmodule F1liveWeb.ErrorJSONTest do
  use F1liveWeb.ConnCase, async: true

  test "renders 404" do
    assert F1liveWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert F1liveWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
