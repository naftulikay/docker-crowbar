# docker-crowbar [![Build Status][travis.svg]][travis] [![Docker Status][docker.svg]][docker]

A Rust [Crowbar][crowbar] development environment in a very restrictive Lambda image.

Available on Docker Hub at [`naftulikay/crowbar`][docker].

## Background

Using [crowbar][crowbar], it's possible to build Rust Lambda functions which simply act a a pseudo-Python native
library. This enables use of Rust, as it's an otherwise unsupported language for Lambda.

For the full background story, [please see the README here][background], which was the ancestor of this Docker image.

## Goals

The goals of this image are to:

 1. Provide a build environment for Crowbar projects which is _consistent_ with the runtime execution environment of
    Lambda Python 3.6 projects.
 2. Provide utilities to make building a Lambda package straightforward and easy.

## Example

To build a project in the local directory:

```shell
docker run -it --rm -e USER_UID="$(id -u)" -e USER_GID="$(id -g)" \
    -v $PWD:/home/rust/project \
  'cd project && cargo build --release' \
  'cd project && create-deployment target/release/liblambda.so target/deploy'
```

This will ensure that user permissions are correct (see the "UID and GID Remapping" section below), will mount the
current directory at `/home/rust/project` within the container, and then will build a release of the shared library,
and then will bundle a zip file containing `liblambda.so` and all linked libraries.

The final zip file created at `target/deploy/lambda.zip` can be uploaded as is to Lambda and should contain everything
necessary to execute at runtime.

## Utilities

A few utilities are provided; please note that these utilities will _not_ be present in the runtime environment. If you
would like to use them at runtime, please bake them into your Lambda deployment zip.

### Configuration and Infrastructure Management

Terraform can be easily installed using [`bin/tfenv`](bin/tfenv). Simply call `tfenv $TERRAFORM_VERSION` to install the
given version of Terraform to `~/.local/bin`.

The latest stable Ansible is also installed.

### UID and GID Remapping

On start of the container, the [`bin/id-remap`](bin/id-remap) script will remap the `rust` user's UID and GID to the
values of the `USER_UID` and `USER_GID` values. This is useful for using the image in varying environments such as
CircleCI, in which the UID is 1001 and the GID is 1002, rather than the usually expected 1000:1000.

Here's how to ensure your file ownership is correct at runtime:

```shell
docker run -it --rm -e USER_UID="$(id -u)" -e USER_GID="$(id -g)"
```

### Create Deployments

There is also a utility for creating ZIP deployments ready for Lambda from Crowbar:
[`bin/create-deployment`](bin/create-deployment). This Python utility will find all dependent libraries (recursively) of
`liblambda.so` and include them in the ZIP deployment archive.

The output archive will look somewhat like this:

```
.
├── lib
│   ├── libpthread.so
│   ├── libselinux.so
│   └── libz.so
└── liblambda.so
```

Lambda's `LD_LIBRARY_PATH` is set to the normal system default, with `.` and `./lib` appended to the end. For anything
not found in `/usr/lib64` and `/usr/local/lib64`, the linker will thus attempt to load the libraries from `.` and then
from `./lib/`.

## License

Licensed at your discretion under either:

 - [MIT](./LICENSE-MIT)
 - [Apache License, Version 2.0](./LICENSE-APACHE)

 [docker]: https://hub.docker.com/r/naftulikay/crowbar/
 [docker.svg]: https://img.shields.io/docker/automated/naftulikay/crowbar.svg?maxAge=2592000
 [travis]: https://travis-ci.org/naftulikay/docker-crowbar
 [travis.svg]: https://travis-ci.org/naftulikay/docker-crowbar.svg?branch=master
 [lambda]: https://docs.aws.amazon.com/lambda/latest/dg/current-supported-versions.html
 [lambda-image]: https://github.com/lambci/docker-lambda
 [crowbar]: https://github.com/ilianaw/rust-crowbar/
 [background]: https://github.com/naftulikay/docker-circleci-lambda-rust#background
