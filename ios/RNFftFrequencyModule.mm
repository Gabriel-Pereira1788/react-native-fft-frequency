#import "RNFftFrequencyModule.h"
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>

@implementation RNFftFrequencyModule
RCT_EXPORT_MODULE()


- (NSArray<NSString *> *)supportedEvents {
  return @[@"onFrequencyDetected"];
}

- (instancetype)init {
  [self setupAudioSession];
  [self requestPermission];
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
  self.eqFilter = [[AVAudioUnitEQ alloc] initWithNumberOfBands:2];
  
  AVAudioUnitEQFilterParameters *highPass = self.eqFilter.bands[0];
  highPass.filterType = AVAudioUnitEQFilterTypeHighPass;
  highPass.frequency = _highPassHz;
  highPass.bypass = NO;
  highPass.bandwidth = 0.5;
  
  AVAudioUnitEQFilterParameters *lowPass = self.eqFilter.bands[1];
  lowPass.filterType = AVAudioUnitEQFilterTypeLowPass;
  lowPass.frequency = _lowPassHz;
  lowPass.bypass = NO;
  lowPass.bandwidth = 0.5;
}

- (void)setupAudioEngine {
  self.audioEngine = [[AVAudioEngine alloc] init];
  AVAudioInputNode *inputNode = [self.audioEngine inputNode];
  AVAudioFormat *format = [inputNode inputFormatForBus:0];
  
  [self.audioEngine attachNode:self.eqFilter];
  [self.audioEngine connect:inputNode to:self.eqFilter format:format];
  [self.audioEngine connect:self.eqFilter to:[self.audioEngine mainMixerNode] format:format];
}

- (void)setupFFT {
  
  self.fftSetup = vDSP_create_fftsetup(log2f(_fftSize), kFFTRadix2);
}

- (void)processAudioBuffer:(AVAudioPCMBuffer *)buffer format:(AVAudioFormat *)format {
  
  if (buffer.frameLength < _fftSize) return;
  
  float *data = buffer.floatChannelData[0];
  
  float window[_fftSize];
  vDSP_blkman_window(window, _fftSize, 0);
  float windowedData[_fftSize];
  vDSP_vmul(data, 1, window, 1, windowedData, 1, _fftSize);
  
  float rms = 0.0;
  vDSP_rmsqv(windowedData, 1, &rms, _fftSize);
  float amplitudeThreshold = 0.02;
  if (rms < amplitudeThreshold) {
    return;
  }
  

  DSPComplex *complexBuffer = (DSPComplex *)malloc(_fftSize * sizeof(DSPComplex));
  for (int i = 0; i < _fftSize; i++) {
    complexBuffer[i].real = windowedData[i];
    complexBuffer[i].imag = 0;
  }
  
  DSPSplitComplex split;
  split.realp = (float *)malloc(_fftSize/2 * sizeof(float));
  split.imagp = (float *)malloc(_fftSize/2 * sizeof(float));
  vDSP_ctoz(complexBuffer, 2, &split, 1, _fftSize/2);
  
  vDSP_fft_zrip(self.fftSetup, &split, 1, log2f(_fftSize), FFT_FORWARD);
  
  float magnitudes[_fftSize/2];
  vDSP_zvabs(&split, 1, magnitudes, 1, _fftSize/2);
  
  float maxMag = 0;
  vDSP_maxv(magnitudes, 1, &maxMag, _fftSize/2);
  
  int maxIndex = 0;
  for (int i = 0; i < _fftSize/2; i++) {
    if (magnitudes[i] == maxMag) {
      maxIndex = i;
      break;
    }
  }
  
  float refinedIndex = maxIndex;
  if (maxIndex > 0 && maxIndex < (_fftSize/2 - 1)) {
    float magLeft = magnitudes[maxIndex - 1];
    float magRight = magnitudes[maxIndex + 1];
    float delta = 0.5f * (magRight - magLeft) / (2 * maxMag - magLeft - magRight);
    refinedIndex = maxIndex + delta;
  }
  
  float sampleRate = format.sampleRate;
  float frequency = refinedIndex * sampleRate / _fftSize;
  
  if (frequency >= _highPassHz && frequency <= _lowPassHz) {
    [self sendEventWithName:@"onFrequencyDetected" body:@(frequency)];
  }
  
  free(complexBuffer);
  free(split.realp);
  free(split.imagp);
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
        return; // Já está parado
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
