# Factual API driver for Bash

This driver is a work-in-progress at the moment, but when it is finished it will
provide an easy way to query Factual data from the command line. To get started,
simply clone this repository and run `./factual`:

```sh
$ git clone git://github.com/stfactual/bash-driver
$ cd bash-driver
```

The one-step setup is to enter your OAuth credentials. The driver automatically
stores them in `~/.factualrc`, so you only need to enter them once. In addition,
this driver makes sure your system has everything it needs to issue API
requests. Right now this includes `curl`, `openssl`, and `base64`.

To setup the driver:

```sh
$ ./factual --check
```

Then run `./factual --help` for a list of available queries and examples. The
output should look like this:

```
Factual driver version 0.0.1
Copyright (c) 2012, Factual

Setup:
  ./factual --check   (this will install your OAuth credentials if necessary)

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

```
