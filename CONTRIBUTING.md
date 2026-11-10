# Contributing

Thanks for helping. The most valuable contribution is a report from a laptop model that hasn't been verified yet.

## Reporting a bug or a new model

[Open an issue](https://github.com/sritulasiram/rog-gaming-center-hackintosh/issues/new/choose) and pick a template. Include:

- Laptop model and macOS version (System card on the dashboard)
- Output of `rogauracore --diagnose`
- Relevant lines from **Status → Events**

Check [Troubleshooting](docs/TROUBLESHOOTING.md) first; most problems are permissions or the USB map.

## Adding a laptop

Follow [Architecture → Adding a laptop](docs/ARCHITECTURE.md#adding-a-laptop). In short: run `rogauracore --diagnose`, add the product ID to `AuraInterfaceSelector.knownProductIDs`, extend `HardwareKey` only if the model sends new codes, add a test for any `AuraCore` change, and update the table in [Hackintosh Notes](docs/HACKINTOSH.md#compatible-laptops).

## Development

```bash
swift build
swift test
```

See [Architecture → Development](docs/ARCHITECTURE.md#development) for running unbundled, Command Line Tools-only testing and hardware checks. CI runs build and tests on every push.

## Pull requests

- Keep changes focused; one topic per pull request.
- Keep hardware-free logic in `AuraCore` with tests. Only `AuraHID` touches IOKit.
- Don't show estimated or placeholder readings: unavailable means unavailable.
- Update the docs and add a line under **Unreleased** in the [changelog](CHANGELOG.md) when behavior changes.

## Security

The app writes to a USB controller and requests Input Monitoring. To report a security issue, please open a private security advisory on GitHub instead of a public issue.
