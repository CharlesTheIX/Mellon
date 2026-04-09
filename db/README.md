# Mellon Postgres Container

This directory contains a minimal Postgres image for local development.

## Prerequisites

- Docker Desktop or a local Docker engine

## Build the Image

From the repository root:

```bash
docker build -t mellon-postgres -f db/Dockerfile db
```

## Start the Container

Run Postgres on port 5432 with a persistent named volume:

```bash
docker run \
  --name mellon-db \
  -e POSTGRES_PASSWORD=mellon \
  -p 5432:5432 \
  -v mellon-pg:/var/lib/postgresql/data \
  mellon-postgres
```

Defaults baked into the image:

- database: `mellon`
- user: `mellon`
- port: `5432`

The password is supplied at runtime with `POSTGRES_PASSWORD`.

## Connect From Mellon or Another Client

Use these connection settings:

```text
host=127.0.0.1
port=5432
database=mellon
user=mellon
password=mellon
```

Example Postgres URL:

```text
postgresql://mellon:mellon@127.0.0.1:5432/mellon
```

## Verify the Database Is Up

Check container status:

```bash
docker ps
```

Tail logs:

```bash
docker logs -f mellon-db
```

Open a `psql` shell inside the container:

```bash
docker exec -it mellon-db psql -U mellon -d mellon
```

## Stop and Remove

Stop the container:

```bash
docker stop mellon-db
```

Remove the container:

```bash
docker rm mellon-db
```

Remove the persistent volume too:

```bash
docker volume rm mellon-pg
```

## Reset the Database

If you want a fresh empty database, remove both the container and the volume, then start it again:

```bash
docker stop mellon-db
docker rm mellon-db
docker volume rm mellon-pg
docker run \
  --name mellon-db \
  -e POSTGRES_PASSWORD=mellon \
  -p 5432:5432 \
  -v mellon-pg:/var/lib/postgresql/data \
  mellon-postgres
```
