---
Template: Device
Name: RandomSignal
Subtitle: simulated noise source
Paclet: WolframInstitute/DocPageExamples
URI: WolframInstitute/DocPageExamples/ref/device/RandomSignal
Description: Simulated uniform noise source registered in the kernel by DocPageExamples
Keywords: [device, noise, random signal, simulation, device framework, testing]
SeeAlso: [FindDevices, DeviceOpen, DeviceRead, DeviceReadTimeSeries, DeviceClose, DeviceObject]
RelatedGuides: []
---

# RandomSignal

RandomSignal is a simulated noise source provided by DocPageExamples for exercising signal-processing pipelines without any hardware. The driver runs entirely in the kernel: every read returns a fresh pseudorandom sample drawn uniformly between -1 and 1. Loading the paclet registers the device class with the device framework; no in-notebook setup is needed.

## Device Discovery

- `FindDevices["RandomSignal"]` lists the simulated device once the paclet has been loaded.
- Registration is purely in-kernel and happens on paclet load; no hardware, external drivers, or services are involved.

## Opening the Device

- `DeviceOpen["RandomSignal"]` opens the simulated device and returns a [DeviceObject]() expression.
- Several RandomSignal devices can be open at once; each `DeviceOpen` allocates a fresh in-kernel handle and returns a device object with its own instance number.

## Device Properties

- `dev["prop"]` gives the current value of a property; `dev["prop"] = val` resets it.

|   |   |
| --- | --- |
| "Amplitude" | nominal peak amplitude of the simulated signal (default 1.) |
| "SampleRate" | nominal sampling rate in samples per second (default 100) |

- The minimal simulated driver stores these settings without acting on them; readings stay uniform between -1 and 1.

## Reading Data

- `DeviceRead[dev]` returns a single pseudorandom sample as a machine real.
- `DeviceReadTimeSeries[dev, {t, dt}]` samples the device every `dt` seconds for `t` seconds of wall-clock time and returns the readings as a [TimeSeries]() object.
- Readings come from the kernel's random generator, so [SeedRandom]() makes a sequence of reads reproducible.

## Closing and Releasing Resources

- `DeviceClose[dev]` closes the device and releases its in-kernel handle.
- Reading from a closed device object generates a message; reopen with `DeviceOpen["RandomSignal"]` to get a fresh instance.

## Examples

### Basic Examples

Load the paclet; loading registers the RandomSignal device class with the device framework:

```wl
Needs["WolframInstitute`DocPageExamples`"]
```

The registered class is now discoverable:

```wl
FindDevices["RandomSignal"]
```

Open the device:

```wl
dev = DeviceOpen["RandomSignal"]
```

Seed the kernel's random generator for reproducibility and read a single sample:

```wl
SeedRandom[1618];
DeviceRead[dev]
```

Collect a burst of samples and plot the simulated waveform:

```wl
samples = Table[DeviceRead[dev], {60}];
ListLinePlot[samples, PlotRange -> {-1.1, 1.1}, Filling -> Axis, AxesLabel -> {"sample", "value"}]
```

Read a stored property at its default value:

```wl
dev["Amplitude"]
```

Reset the property and read it back:

```wl
dev["Amplitude"] = 0.5;
dev["Amplitude"]
```

`DeviceReadTimeSeries` acquires in real wall-clock time, so it is shown unevaluated here:

```wl
#| eval: false
DeviceReadTimeSeries[dev, {1, 0.1}]
```

Close the device when done:

```wl
DeviceClose[dev]
```
