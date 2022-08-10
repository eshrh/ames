# jq replacement for regex

This uses [`jq`](https://stedolan.github.io/jq/) as a replacement
for the `sed` regex-based JSON parser in `check_response()`.
The default implementation will produce improper error messages if the
error text contains the literals `,` or `}`, e.g. if the JSON response is
```json
{"result": null, "error": "Everything past here: } is lost!"}
```
it will display
```text
Everything past here
```
Using `jq` instead will correctly parse the error message:
```text
Everything past here: } is lost!
```

### Requirements

`jq` is packaged as `jq` in Community.

### Caveats

None.

