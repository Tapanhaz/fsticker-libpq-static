
# fsticker-libpq-static

Prebuilt, statically-linked `libpq` (the PostgreSQL C client library),
published as versioned GitHub Release assets for one consumer:
[`fsticker`](https://github.com/Tapanhaz/fsticker)'s optional TimescaleDB
candle sink.

This is not a general-purpose libpq distribution. It exists so `fsticker`'s
CMake build can `file(DOWNLOAD ...)` a known-good static archive per
platform instead of building PostgreSQL from source on every CI run.

## What's in a release

Each release (tagged `pq<postgres-tag>`, e.g. `pq-REL_16_4`) attaches, per
platform:

```
libpq-<postgres-tag>-<platform>.tar.gz
libpq-<postgres-tag>-<platform>.tar.gz.sha256
```

containing:

```
include/
  libpq-fe.h
  postgres_ext.h
  pg_config_ext.h
lib/
  libpq.a      (or .lib on Windows)
```

Platforms: `linux-x86_64`, `linux-aarch64`, `macos-arm64`, `macos-x86_64`,
`windows-amd64`, `windows-arm64`.

## Build characteristics

- **Static only.** `-Ddefault_library=static` — no shared `libpq.so` /
  `.dylib` / `.dll` is ever produced, so there's nothing for a downstream
  consumer's machine to fail to locate at runtime.
- **Minimal feature set.** SSL, GSSAPI, LDAP, PAM, systemd, SELinux,
  Bonjour, readline, zlib/lz4/zstd, ICU, LLVM/JIT, NLS, docs, and the
  PL/Perl/Python/Tcl language bindings are all disabled. None of these are
  needed to `PQconnectdb` / `PQexecParams` / `PQfinish` against a
  Postgres/TimescaleDB server, and each one is either a dynamic runtime
  dependency or a build-time dependency this project doesn't want to
  require.
- **No TLS to Postgres.** Because SSL is disabled, connections built with
  this library use plain TCP — `sslmode=require` will fail. If your
  Postgres/TimescaleDB endpoint requires TLS, you currently need a custom
  build with `-Dssl=openssl` (linked against the same static OpenSSL
  `fsticker` already vendors) — not yet automated here. contributions
  welcome.

## Building locally

```bash
./build_libpq.sh REL_16_4 linux-x86_64
```

Requires `git`, `meson`, `ninja`, `bison`, `flex`, and a C compiler on
`PATH`. Output lands in `./dist`.

## Publishing a new version

```bash
git tag pq-REL_16_4
git push origin pq-REL_16_4
```

pushes a tag matching `pq*`, which triggers the workflow to build every
platform and attach the archives + checksums to a GitHub Release.

## Consuming from `fsticker`

`fsticker`'s `CMakeLists.txt` downloads the matching archive for the host
platform, verifies its SHA-256 against a pinned value, and links the
static library directly into the extension — see `FSTICKER_PQ_RELEASE_TAG`
and `FSTICKER_PQ_SHA256_<platform>` in that project's build.

## License

PostgreSQL source (and therefore the built `libpq.a`/headers here) is
distributed under the [PostgreSQL License](https://www.postgresql.org/about/licence/),
a permissive OSI-approved license. This repo's own build scripts are
MIT-licensed.