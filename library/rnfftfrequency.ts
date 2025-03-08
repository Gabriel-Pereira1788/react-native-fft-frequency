import NativeFftFrequencyModule, {
  fftAudioEmitter,
  type FFTConfiguration,
} from '../src/NativeFftFrequencyModule';

class RNFFTFrequency {
  start() {
    NativeFftFrequencyModule.start();
  }

  stop() {
    NativeFftFrequencyModule.stop();
  }

  setConfiguration(configuration: FFTConfiguration) {
    NativeFftFrequencyModule.setConfiguration(configuration);
  }

  addListener(
    eventName: 'onFrequencyDetected',
    listener: (frequency: number) => void
  ) {
    fftAudioEmitter.addListener(eventName, listener);
  }

  removeListeners(eventName: 'onFrequencyDetected') {
    fftAudioEmitter.removeAllListeners(eventName);
  }
}

const rnfftFrequency = new RNFFTFrequency();
export { rnfftFrequency };
