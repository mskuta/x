# Description

Each RIR (Regional Internet Registry) and their parent NRO (Number Resource Organization) publish a daily updated and freely available "delegated-extended file" containing information on the distribution of Internet number resources. From it, this script extracts IP ranges grouped by country and outputs them in [P2P plaintext format](https://en.wikipedia.org/wiki/PeerGuardian#P2P_plaintext_format).


# Usage

```
gawk -f rirccfilter.gawk [-v cc=CC]
```

`CC` optionally specifies an ISO 3166 2-letter code. The result will contain only IP ranges belonging to the corresponding country. Without country code all records will be processed.

RIR datasets can be passed either as filename or via stdin. The result is written to stdout. Metadata is shown on stderr.

Hint: Whereas datasets of individual RIRs contain only records about countries for which they are responsible, the file of the NRO includes the records of all RIRs.

## Example

Download the latest RIR dataset, filter IP addresses from Germany and store them in file `blocklist`:
```shell
wget -O - -q https://ftp.ripe.net/pub/stats/ripencc/nro-stats/latest/nro-delegated-stats | gawk -f rirccfilter.gawk -v cc=DE >blocklist
```


