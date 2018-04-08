# docker-crowbar [![Build Status][travis.svg]][travis] [![Docker Status][docker.svg]][docker]

A Rust development environment in a very restrictive Lambda image.

Available on Docker Hub at [`naftulikay/crowbar`][docker].

## Background

Using [crowbar][crowbar], it's possible to build Rust Lambda functions which simply act a a pseudo-Python native
library. This enables use of Rust, as it's an otherwise unsupported language for Lambda.

To make sure that runtime libraries match compile-time libraries, I built
[`naftulikay/crowbar`][crowbar]. In accordance with [Amazon's documentation][lambda]
, I pinned the base image to `amazonlinux:2017.03.1.20170812`, the version that Lambda uses at runtime.

Previously, I was simply building within a CentOS 7 Docker image which actually worked quite well. The environment was
similar enough to make most things work.

### Enter OpenSSL

As soon as my library started linking against `libssl` and `libcrypto`, I got really strange errors about a linked
library needing OpenSSL 1.0.2 but the current `libssl` was version 1.0.1. Apparently, during my image build, installing
or upgrading any packages forced OpenSSL to be upgraded to 1.0.2, which was _not_ the OpenSSL version present in the
actual Lambda runtime environment. Despite using the exact version of Amazon Linux, the fact that certain upgrades
were necessary, my build and runtime environments differed in incompatible ways.

#### Vendoring Shared Libraries

Since Lambda supplied a `LD_LIBRARY_PATH` of `.` and `lib/` of the zip archive, I wrote a recursive Python program
which would find all linked libraries for my `liblambda.so` and vendor them into `lib/`. However, since the priority
set by Amazon Linux for Lambda is likely something like this:

```shell
LD_LIBRARY_PATH="/lib64:/usr/lib64:/usr/local/lib64:$PWD:$PWD/lib"
```

...the linker will first find OpenSSL in `/usr/lib64` and will dynamically link against that rather than my bundled
OpenSSL shared library.

I will still do this, because if I install, say, `libsodium`, and this library is not present at runtime in the image,
the linker _will_ eventually find the library and things will be happy.

#### Pinning the OpenSSL Package

I tried to pin OpenSSL to 1.0.1 using a yum plugin, but this broke everything else: many libraries including Python
required OpenSSL >= 1.0.2, which broke installing packages. To make matters worse, Amazon Linux only retains a fixed
number of revisions for packages in their repository, so installing OpenSSL 1.0.1 was simply not possible.

#### Statically Compiling OpenSSL

Angry at OpenSSL and with some environment variables, I configured Cargo/`openssl` to statically build OpenSSL and
include it directly in the output shared library. The package repositories provide `openssl-static` which contains
`libssl.a` and other archives for static linking, which meant that I didn't need to rebuild OpenSSL from source :tada:

The first hangup I ran into was that the Rust [`openssl`][rust-openssl] crate's instructions were wrong for static
compilation. They essentially state:

> Set `OPENSSL_STATIC=1` during Cargo execution to statically build OpenSSL into the binary.

Unfortunately, [this was not true][openssl-bug]. Another [brave soul saved the day][openssl-workaround] and dug into
the `openssl` `build.rs` build script and found that in order to get static compilation working, _three_ environment
variables must be set:

```shell
OPENSSL_STATIC=1 \
  OPENSSL_LIB_DIR=/usr/lib64 \
  OPENSSL_INCLUDE_DIR=/usr/include
    cargo build --release --lib
```

I assembled [a demo project][rust-openssl-static-example] to prove this out and with a simple test, was able to prove
it was working:

```shell
if ldd target/release/liblambda.so | grep -qiP 'lib(ssl|crypto)' ; then
  (
    ldd target/release/liblambda.so
    echo "ERROR: liblambda.so is linked to libssl and/or libcrypto."
  ) >&2
  exit 1
fi
```

Finally, we had static compilation of OpenSSL into the shared library working.

For this use case, it worked just fine:

```rust
#[macro_use(lambda)]
extern crate crowbar;
extern crate openssl;
#[macro_use]
extern crate cpython;

lambda!(|_event, _context| {
  openssl::init();
});
```

Everything was happy under this setup. However, as soon as I brought in [`rusoto`][rusoto], it pulled in other updated
dependencies and again I was in linking hell:

```shell
/usr/bin/ld: /home/vagrant/.cache/cargo/target/debug/liblambda.so: version node not found for symbol SSLeay_version@OPENSSL_1.0.1
/usr/bin/ld: failed to set dynamic section sizes: Bad value
```
 I then changed my crate type to `staticlib` and aimed to
transform it into a pseudo-shared library after the fact. This didn't work and was extremely brittle and deadly
frustrating.

### Back to Basics

I couldn't see a way to succeed here and I spent hours in abject despair for the time I had lost on this.
Then, [a brave and honorable White Knight on the Rust discourse forums][bravery] mentioned another image
made from a tarball of the environment at runtime of actual Lambda functions, [`lambci/lambda`][lambda-image].

I spun up one of these Docker images and tested package upgrades and the good news is that the maintainers here seem to
have pinned all of the shared libraries without all the madness so that installing packages _do not upgrade OpenSSL_.

I'm now seeking to prove this out by building this container.

## License

Licensed at your discretion under either:

 - [MIT](./LICENSE-MIT)
 - [Apache License, Version 2.0](./LICENSE-APACHE)

 [docker]: https://hub.docker.com/r/naftulikay/crowbar/
 [docker.svg]: https://img.shields.io/docker/automated/naftulikay/crowbar.svg?maxAge=2592000
 [travis]: https://travis-ci.org/naftulikay/docker-crowbar
 [travis.svg]: https://travis-ci.org/naftulikay/docker-crowbar.svg?branch=master
 [lambda]: https://docs.aws.amazon.com/lambda/latest/dg/current-supported-versions.html
 [openssl-workaround]: https://stackoverflow.com/a/49268370/128967
 [rust-openssl-static-example]: https://github.com/naftulikay/rust-openssl-static-example
 [openssl-bug]: https://github.com/sfackler/rust-openssl/issues/877
 [rusoto]: https://rusoto.org/
 [crowbar]: https://github.com/naftulikay/docker-crowbar
 [rust-openssl]: https://github.com/sfackler/rust-openssl
 [bravery]: https://users.rust-lang.org/t/statically-linking-parts-of-a-shared-library/16171/23?u=naftulikay
 [lambda-image]: https://github.com/lambci/docker-lambda
 [crowbar]: https://github.com/ilianaw/rust-crowbar/
