defmodule Plausible.Repo.Migrations.AddTagsToSites do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :tags, {:array, :string}, default: []
    end

    create index(:sites, [:tags], using: :gin)
  end
end
