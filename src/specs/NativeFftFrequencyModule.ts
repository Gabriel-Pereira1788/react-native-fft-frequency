import { NativeEventEmitter, TurboModuleRegistry } from 'react-native';
import type { TurboModule } from 'react-native';
/**
 * Represents the configuration for Fast Fourier Transform (FFT) processing.
 * This interface defines the parameters required to set up an FFT operation,
 * including the size of the FFT and the frequency range to analyze.
 *
 * @interface FFTConfiguration
 */
export interface FFTConfiguration {
  /**
   * The size of the FFT (Fast Fourier Transform) window.
   * This determines the number of samples used for each FFT calculation.
   * Must be a power of 2 (e.g., 256, 512, 1024, 2048, 4096).
   * A larger FFT size provides better frequency resolution but increases computational cost.
   *
   * @type {number}
   * @example
   * const config = { fftSize: 4096, highPassHz: 70, lowPassHz: 400 };
   */
  fftSize: number;

  /**
   * The lower frequency threshold (in Hz) for the high-pass filter.
   * Frequencies below this value will be attenuated or removed from the signal.
   * This is useful for eliminating low-frequency noise (e.g., background hum).
   *
   * @type {number}
   * @example
   * const config = { fftSize: 4096, highPassHz: 70, lowPassHz: 400 };
   */
  highPassHz: number;

  /**
   * The upper frequency threshold (in Hz) for the low-pass filter.
   * Frequencies above this value will be attenuated or removed from the signal.
   * This is useful for eliminating high-frequency noise or focusing on a specific frequency range.
   *
   * @type {number}
   * @example
   * const config = { fftSize: 4096, highPassHz: 70, lowPassHz: 400 };
   */
  lowPassHz: number;
}
export interface Spec extends TurboModule {
  start(): void;
  stop(): void;
  setConfiguration(fftConfiguration: FFTConfiguration): void;
  addListener(eventType: string): void;
  removeListeners(): void;
}

const NativeFftFrequencyModule = TurboModuleRegistry.getEnforcing<Spec>(
  'RNFftFrequencyModule'
);
export const fftAudioEmitter = new NativeEventEmitter(NativeFftFrequencyModule);

export default NativeFftFrequencyModule;
