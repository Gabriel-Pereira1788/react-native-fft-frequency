# React Native FFT Frequency

A React Native library for real-time audio frequency detection using Fast Fourier Transform (FFT). This native module provides efficient frequency analysis capabilities for both Android and iOS platforms.

## Features

- Real-time audio frequency detection
- Configurable FFT parameters
- High-performance native implementation
- Easy-to-use React Native hooks
- Support for both Android and iOS
- Customizable frequency range and sensitivity

## Installation

```bash
npm install react-native-fft-frequency
# or
yarn add react-native-fft-frequency
```

### iOS Setup
Add the following to your `Podfile`:

```ruby
pod 'react-native-fft-frequency', :path => '../node_modules/react-native-fft-frequency'
```

Then run:
```bash
cd ios && pod install
```

### Android Setup
No additional setup required for Android.

## Usage

### Basic Example

```typescript
import { useFrequency, rnfftFrequency } from 'react-native-fft-frequency';

function App() {
  const frequency = useFrequency();

  const startListening = () => {
    rnfftFrequency.start();
  };

  const stopListening = () => {
    rnfftFrequency.stop();
  };

  return (
    <View>
      <Text>Current Frequency: {frequency} Hz</Text>
      <Button title="Start" onPress={startListening} />
      <Button title="Stop" onPress={stopListening} />
    </View>
  );
}
```

### Advanced Configuration

You can customize the FFT parameters using the `setConfiguration` method:

```typescript
rnfftFrequency.setConfiguration({
  fftSize: 4096,        // FFT size (power of 2)
  highPassHz: 70.0,     // High-pass filter frequency
  lowPassHz: 400.0,     // Low-pass filter frequency
  calibrationOffset: 1.0 // Calibration offset for frequency detection
});
```

## API Reference

### Hooks

#### `useFrequency()`
A React hook that returns the current detected frequency in Hz.

### Methods

#### `RNFFTFrequency.start()`
Starts the frequency detection.

#### `RNFFTFrequency.stop()`
Stops the frequency detection.

#### `RNFFTFrequency.setConfiguration(config: FFTConfiguration)`
Configures the FFT parameters.

### Types

```typescript
interface FFTConfiguration {
  fftSize?: number;
  highPassHz?: number;
  lowPassHz?: number;
  calibrationOffset?: number;
}
```

## Technical Details

The library uses native implementations to perform real-time audio processing:

- **Android**: Uses AudioRecord API with native FFT implementation
- **iOS**: Implements audio capture using AVFoundation and performs FFT analysis
- Sample rate: 44.1kHz
- Default FFT size: 4096 samples
- Default frequency range: 70Hz - 400Hz

## Permissions

The library requires microphone permissions:

### Android
Add to your `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

### iOS
Add to your `Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to microphone for frequency detection.</string>
```

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details.

## License

MIT License - see the [LICENSE](LICENSE) file for details.
