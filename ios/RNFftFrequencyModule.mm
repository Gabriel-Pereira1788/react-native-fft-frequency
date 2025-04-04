#import "RNFftFrequencyModule.h"
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#import "CoreAudioKit/CoreAudioKit.h"

@implementation RNFftFrequencyModule
RCT_EXPORT_MODULE()


- (NSArray<NSString *> *)supportedEvents {
  return @[@"onFrequencyDetected"];
}

- (instancetype)init {
  [self setupAudioSession];
  [self requestPermission];
  
  self.calibrationOffset = 1.0f;
  return self;
}

- (void)start {
  
  if (self.isCapturing || self.permissionGranted == false) {
    
    return;
  }

  
  [self setupEQFilter];
  [self setupAudioEngine];
  [self setupFFT];
  
  self.isCapturing = YES;
  
  AVAudioFormat *format = [self.audioEngine.inputNode inputFormatForBus:0];
  
  
  [self.eqFilter installTapOnBus:0 bufferSize:_fftSize format:format block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
    [self processAudioBuffer:buffer format:format];
  }];
  
  NSError *error = nil;
  if (![self.audioEngine startAndReturnError:&error]) {
    NSLog(@"Error on init audio engine: %@", error.localizedDescription);
  }
}
- (void) requestPermission {
  [_session requestRecordPermission:^(BOOL granted) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (granted) {
        self.permissionGranted = true;
      } else {
        self.permissionGranted = false;
      }
    });
  }];
}

- (void)setupAudioSession {
  NSError *sessionError = nil;
  self.session = [AVAudioSession sharedInstance];
  
  [self.session setCategory:AVAudioSessionCategoryPlayAndRecord error:&sessionError];
  if (sessionError) {
    NSLog(@"Erro on define session categories: %@", sessionError.localizedDescription);
    return;
  }
  
  [self.session setMode:AVAudioSessionModeDefault error:&sessionError];
  if (sessionError) {
    NSLog(@"Error on define session mode: %@", sessionError.localizedDescription);
    return;
  }
  
  Float64 preferredSampleRate = 44100;
  if ([self.session respondsToSelector:@selector(setPreferredSampleRate:error:)]) {
    [self.session setPreferredSampleRate:preferredSampleRate error:&sessionError];
    if (sessionError) {
      NSLog(@"Error on define preferred sample rate: %@", sessionError.localizedDescription);
      sessionError = nil; // Ignora o erro e continua
    }
  }
  
  [self.session setActive:YES error:&sessionError];
  if (sessionError) {
    NSLog(@"Error on active session: %@", sessionError.localizedDescription);
  }
}

- (void)setupEQFilter {
  self.eqFilter = [[AVAudioUnitEQ alloc] initWithNumberOfBands:1];
  AVAudioUnitEQFilterParameters *bandPass = self.eqFilter.bands[0];
  bandPass.filterType = AVAudioUnitEQFilterTypeBandPass;
  bandPass.frequency = (_highPassHz + _lowPassHz) / 2.0;
  bandPass.bandwidth = _lowPassHz - _highPassHz;
  
  bandPass.bypass = NO;
}


- (void)setupAudioEngine {
    @try {
        self.audioEngine = [[AVAudioEngine alloc] init];
        if (!self.audioEngine) {
            NSLog(@"Erro: Errpr on init AVAudioEngine");
            return;
        }

        AVAudioInputNode *inputNode = [self.audioEngine inputNode];
        AVAudioFormat *format = [inputNode inputFormatForBus:0];

        if (!inputNode || !format) {
            NSLog(@"Erro: Error on node entering.");
            return;
        }

        if (!self.eqFilter) {
            NSLog(@"Erro: eqFilter no initialized.");
            return;
        }

        [self.audioEngine attachNode:self.eqFilter];
        [self.audioEngine connect:inputNode to:self.eqFilter format:format];
        [self.audioEngine connect:self.eqFilter to:[self.audioEngine mainMixerNode] format:format];

    } @catch (NSException *exception) {
        NSLog(@"Exception configure audio engine: %@, %@", exception.name, exception.reason);
    }
}


- (void)setupFFT {
  
  self.fftSetup = vDSP_create_fftsetup(log2f(_fftSize), kFFTRadix2);
}

- (void)processAudioBuffer:(AVAudioPCMBuffer *)buffer format:(AVAudioFormat *)format {
  if (buffer.frameLength < _fftSize) return;
  
  float *data = buffer.floatChannelData[0];
  
  float window[_fftSize];
  vDSP_hann_window(window, _fftSize, vDSP_HANN_NORM);
  float windowedData[_fftSize];
  vDSP_vmul(data, 1, window, 1, windowedData, 1, _fftSize);
  
  float rms = 0.0;
  vDSP_rmsqv(windowedData, 1, &rms, _fftSize);
  float amplitudeThreshold = 0.02;
  if (rms < amplitudeThreshold) {
    return;
  }
  
  float frequency = [self detectPitchWithBuffer:windowedData
                                     bufferSize:_fftSize
                                     sampleRate:format.sampleRate];
  
  frequency -= self.calibrationOffset;
  if (frequency >= _highPassHz && frequency <= _lowPassHz) {
    [self sendEventWithName:@"onFrequencyDetected" body:@(frequency)];
  }
}

- (float)detectPitchWithBuffer:(float *)buffer
                    bufferSize:(int)bufferSize
                    sampleRate:(float)sampleRate {
  int tauMax = bufferSize / 2;
  
  float *d = (float *)malloc(sizeof(float) * tauMax);
  float *cmndf = (float *)malloc(sizeof(float) * tauMax);
  
  d[0] = 0;
  for (int tau = 1; tau < tauMax; tau++) {
    float sum = 0;
    for (int j = 0; j < bufferSize - tau; j++) {
      float diff = buffer[j] - buffer[j + tau];
      sum += diff * diff;
    }
    d[tau] = sum;
  }
  
  cmndf[0] = 1;
  float runningSum = 0;
  for (int tau = 1; tau < tauMax; tau++) {
    runningSum += d[tau];
    cmndf[tau] = (runningSum > 0) ? (d[tau] * tau / runningSum) : 1.0f;
  }
  
  float threshold = 0.15f;
  int tauEstimate = -1;
  
  for (int tau = 1; tau < tauMax; tau++) {
    if (cmndf[tau] < threshold) {
      while (tau + 1 < tauMax && cmndf[tau + 1] < cmndf[tau]) {
        tau++;
      }
      tauEstimate = tau;
      break;
    }
  }

  if (tauEstimate < 0) {
    float minCMND = FLT_MAX;
    for (int tau = 1; tau < tauMax; tau++) {
      if (cmndf[tau] < minCMND) {
        minCMND = cmndf[tau];
        tauEstimate = tau;
      }
    }
  }
  
  float pitch = 0;
  if (tauEstimate > 0 && tauEstimate < tauMax - 1) {

    float s0 = cmndf[tauEstimate - 1];
    float s1 = cmndf[tauEstimate];
    float s2 = cmndf[tauEstimate + 1];
    float denominator = (2 * s1 - s2 - s0);
    float betterTau = (denominator != 0) ? tauEstimate + (s2 - s0) / (2 * denominator) : tauEstimate;
    pitch = sampleRate / betterTau;
  } else if (tauEstimate > 0) {
    pitch = sampleRate / tauEstimate;
  }
  
  free(d);
  free(cmndf);
  
  return pitch;
}




- (void)removeListeners {
  [self stopObserving];
}

- (void)setConfiguration:(JS::NativeFftFrequencyModule::FFTConfiguration &)fftConfiguration {
  double fftSizeValue = fftConfiguration.fftSize();
  self.fftSize = round(fftSizeValue);
  self.highPassHz = fftConfiguration.highPassHz();
  self.lowPassHz = fftConfiguration.lowPassHz();
}

#pragma clang diagnostic ignored "-Wnonnull"
- (void)stop {
  if (!self.isCapturing) {
    return;
  }
  
  [self.audioEngine stop];
  [self.audioEngine reset];
  
  [self.eqFilter removeTapOnBus:0];
  
  
  if (self.fftSetup != nil) {
    vDSP_destroy_fftsetup(self.fftSetup);
    self.fftSetup = nil;
  }
  
  self.audioEngine = nil;
  self.eqFilter = nil;
  
  NSError *error = nil;
  [self.session setActive:NO error:&error];
  if (error) {
    NSLog(@"Erro ao desativar AVAudioSession: %@", error.localizedDescription);
  }
  
  self.isCapturing = NO;
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
(const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeFftFrequencyModuleSpecJSI>(params);
}

@end
