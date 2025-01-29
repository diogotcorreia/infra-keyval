# infra-keyval

This project exists because I wanted a way to store the path of
the last successfully built (and cached) derivation for each of
my NixOS systems.

It simply provides a read and write endpoint for a key-value store,
with the store backend being a PostgreSQL database.
Reading can be performed without any authentication whatsoever, but
writing requires an access token.

## Running

There are no options, but there are a few environment variables:

- `LISTEN_ADDR`: the address to bind the http server to (default: `[::1]:3000`)
- `DB_URL`: the database connection URL (default: `postgresql://localhost:5432`)
- `WRITE_TOKEN`: the token needed to perform write actions (required)

When those are set, you can run `cargo run --release` or build
the binary with `cargo build --release` and then running
the resulting binary in `./target/release/infra-keyval`.

## Endpoints

- `GET /`: always returns body `OK` and status `200`
- `GET /{key}`: returns value of key in body (raw value) and status `200`,
  or `404` if not found
- `POST /{key}`: expects access token in `Authorization: <token>` header,
  and value will be the raw body content, returning status `201`
