package com.rnfftfrequency

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.annotations.ReactModule
import android.annotation.SuppressLint

import com.facebook.react.bridge.ReadableMap
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import kotlin.math.*
import org.jtransforms.fft.FloatFFT_1D

@ReactModule(name = RNFftFrequencyModule.NAME)
class RNFftFrequencyModule(reactContext: ReactApplicationContext) :
  NativeFftFrequencyModuleSpec(reactContext) {
        private var isCapturing = false
    private var audioRecord: AudioRecord? = null
    private val sampleRate = 44100
    private val amplitudeThreshold = 0.02

    private var fftSize = 4096
    private var highPassHz = 70.0
    private var lowPassHz = 400.0

    @SuppressLint("MissingPermission")
    override fun start() {
        if (isCapturing) {
            return
        }

        // Configura o AudioRecord para captura de áudio
        val bufferSize = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )

        audioRecord?.startRecording()
        isCapturing = true

        Thread {
            val buffer = ShortArray(fftSize)
            val window = hannWindow(fftSize)

            while (isCapturing) {
                val bytesRead = audioRecord?.read(buffer, 0, fftSize) ?: 0

                if (bytesRead > 0) {
                    val floatBuffer = buffer.map { it.toFloat() / Short.MAX_VALUE }.toFloatArray()
                    val windowedData = applyWindow(floatBuffer, window)

                    val rms = calculateRMS(windowedData)
                    if (rms < amplitudeThreshold) {
                        println("RMS: $rms Threshold: $amplitudeThreshold")
                        continue
                    }

                    val fftResult = performFFT(windowedData)

                    val frequency = findDominantFrequency(fftResult, sampleRate)

                    println("Test $frequency")
                    if (frequency in highPassHz..lowPassHz) {
                        onFrequencyDetected(frequency.toDouble())
                    }
                }
            }
        }.start()
    }

    override fun stop() {
        isCapturing = false
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
    }

    private fun hannWindow(size: Int): FloatArray {
        return FloatArray(size) { i ->
            0.5f * (1 - cos(2 * PI * i / (size - 1))).toFloat()
        }
    }

    private fun applyWindow(signal: FloatArray, window: FloatArray): FloatArray {
        return FloatArray(signal.size) { i ->
            signal[i] * window[i]
        }
    }

    private fun calculateRMS(signal: FloatArray): Float {
        var sum = 0f
        for (value in signal) {
            sum += value * value
        }
        return sqrt(sum / signal.size)
    }

    private fun findDominantFrequency(fftResult: FloatArray, sampleRate: Int): Float {
        var maxMagnitude = 0f
        var maxIndex = 0

        for (i in 1 until fftResult.size / 2) {
            if (fftResult[i] > maxMagnitude) {
                maxMagnitude = fftResult[i]
                maxIndex = i
            }
        }

        val refinedIndex = if (maxIndex > 0 && maxIndex < fftResult.size  - 1) {
            val magLeft = fftResult[maxIndex - 1]
            val magRight = fftResult[maxIndex + 1]
            val delta = 0.5f * (magRight - magLeft) / (2 * maxMagnitude - magLeft - magRight)
            maxIndex + delta
        } else {
            maxIndex.toFloat()
        }

        return refinedIndex * sampleRate / fftSize
    }

    private fun onFrequencyDetected(frequency: Double) {
        println("Frequência detectada: $frequency Hz")

        reactApplicationContext.emitDeviceEvent("onFrequencyDetected",frequency)
    }

    private fun performFFT(signal: FloatArray): FloatArray {
        val fft = FloatFFT_1D(fftSize.toLong())
        val fftInput = signal.copyOf()

        fft.realForward(fftInput)

        val magnitudes = FloatArray(fftSize / 2)
        for (i in 0 until fftSize / 2) {
            val real = fftInput[2 * i]
            val imag = fftInput[2 * i + 1]
            magnitudes[i] = sqrt(real * real + imag * imag)
        }

        return magnitudes
    }


    override fun setConfiguration(fftConfiguration: ReadableMap?) {
        if (fftConfiguration != null) {
            highPassHz = fftConfiguration.getDouble("highPassHz")
            lowPassHz = fftConfiguration.getDouble("lowPassHz")
            fftSize = fftConfiguration.getInt("fftSize")
        }
    }

    override fun addListener(eventType: String?) {}

    override fun removeListeners() {}
  override fun getName(): String {
    return NAME
  }

  companion object {
    const val NAME = "RNFftFrequencyModule"
  }
}
