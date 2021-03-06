# Factual API driver for Bash

This driver is a work-in-progress at the moment, but when it is finished it will
provide an easy way to query Factual data from the command line. To get started,
simply clone this repository and run `./factual`:

```sh
$ git clone git://github.com/stfactual/bash-driver
$ cd bash-driver
```

## Driver setup

```sh
$ ./factual --init
```

In the process, it will ask you for your OAuth credentials and store them into
`~/.factual/factual-auth.yaml`. It also verifies that you have `curl` and
`openssl` in your `$PATH`, and makes a test query to the Factual API using the
OAuth credentials you provide.

## Working with the driver

Run `./factual --help` for a list of available queries and examples. The output
should look like this:

```
Factual driver version 0.0.2
Copyright (c) 2012, Factual

Setup:
  ./factual --init     # sets up your OAuth credentials and prints usage
  ./factual --check    # verify that you have necessary dependencies

Querying:
  ./factual [-v|--verbose] --schema table-name
  ./factual [-v|--verbose] [--fetch] table-name ...
  ./factual [-v|--verbose] --facets table-name fields ...
  ./factual [-v|--verbose] --resolve ...
  ./factual [-v|--verbose] --match ...
  ./factual [-v|--verbose] --geocode latitude longitude

To see query-specific options:
  ./factual --fetch-usage
  ./factual --facets-usage
  ./factual --resolve-usage
  ./factual --match-usage
  ./factual --geocode-usage

For details about writing JSON objects:
  ./factual --json-usage
```

## Using as a library

You can use the Factual driver from inside another shell script by sourcing
`factual-lib.sh`. Then each toplevel driver command will be available as a bash
function. For example:

```sh
source factual-lib.sh

./factual --geocode $lat $lng
factual-geocode $lat $lng

./factual --fetch restaurants-us ...
factual-fetch restaurants-us ...
```

This applies to all of the driver's commands, including `--check`, `--init`, and
`--x-usage`. You can trigger verbose output by setting the `$factual_verbose`
variable:

```sh
factual_verbose='-v'
```

This corresponds to using `--verbose` on the command line.

Note that the driver prints all interactions to standard error; during normal
operation, only the JSON returned by the Factual API is written to standard out.

## Formatting the output

Normally the JSON generated by the driver is compressed; that is, it is totally
unformatted and contains no whitespace. There are several tools you can use to
fix this, but the easiest is probably Python:

```sh
$ ./factual places -q starbucks | python -mjson.tool
```

## Running unit tests

All unit tests live in `test/` and are individual scripts that run the main
`factual` program. They assume that you've already run `./factual --init`, but
otherwise have no state. To run tests:

```sh
$ cd test       # unfortunately, this matters at the moment
$ ./unicode-test
```

More tests will be added in the future, along with a better way to run them.
