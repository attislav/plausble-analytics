defmodule PlausibleWeb.Api.ExternalSitesLiteController do
  @moduledoc """
  CE/self-host friendly Sites listing endpoint.

  Why this exists:
  - Upstream Plausible's full Sites/Teams provisioning API is gated behind EE/Enterprise.
  - Stats API tokens can still be used in self-hosted installs.

  This controller provides a minimal read-only endpoint to list domains accessible
  to the API key user, so external tools (e.g. OpenClaw skills) can discover site_ids
  without maintaining a manual list.

  Auth:
  - Bearer token via PlausibleWeb.Plugs.AuthorizePublicAPI

  Output:
  - `{ "sites": [ { "domain": "example.com" }, ... ] }`
  """

  use PlausibleWeb, :controller

  alias Plausible.Sites

  # GET /api/v1/sites
  def index(conn, params) do
    user = conn.assigns[:current_user]
    team = conn.assigns[:current_team]

    # optional limit (defaults to 200)
    limit =
      case Integer.parse(to_string(Map.get(params, "limit", ""))) do
        {n, _} when n > 0 and n <= 1000 -> n
        _ -> 200
      end

    # Sites.list/3 returns a pagination struct with :entries
    page = Sites.list(user, %{page_size: limit}, team: team)

    sites =
      Enum.map(page.entries, fn site ->
        %{
          domain: site.domain
        }
      end)

    json(conn, %{sites: sites, meta: %{limit: limit}})
  end
end
