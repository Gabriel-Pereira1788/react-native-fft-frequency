package com.rnfftfrequency

import android.Manifest
import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule
import kotlinx.coroutines.*
import org.jtransforms.fft.FloatFFT_1D
import kotlin.math.*

@ReactModule(name = RNFftFrequencyModule.NAME)
class RNFftFrequencyModule(reactContext: ReactApplicationContext) :
  NativeFftFrequencyModuleSpec(reactContext) {

  private var isCapturing = false
  private var audioRecord: AudioRecord? = null
  private val sampleRate = 44100
  private val amplitudeThreshold = 0.02f

  private var fftSize = 4096
  private var highPassHz = 70.0f
  private var lowPassHz = 400.0f
  private var calibrationOffset = 1.0f

  private val scope = CoroutineScope(Dispatchers.IO)

  init {
    requestPermission()
  }

  @SuppressLint("MissingPermission")
  override fun start() {

    if (ContextCompat.checkSelfPermission(
        reactApplicationContext,
        Manifest.permission.RECORD_AUDIO
      ) != PackageManager.PERMISSION_GRANTED
    ) {
      
      return
    }
    if (isCapturing) {
      return
    }

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
    Log.d("CAIU-AQUI","START");
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
            continue
          }

          val frequency = detectPitch(windowedData, sampleRate.toFloat())
          val calibratedFrequency = frequency - calibrationOffset
          Log.d("FREQUENCY","FREQUENCY: $frequency , CALIBRATED_FREQUENCY: $calibratedFrequency")
          if (calibratedFrequency in highPassHz..lowPassHz) {
            onFrequencyDetected(calibratedFrequency.toDouble())
          }
        }
      }
    }.start()
  }

  private fun requestPermission() {
    if (ContextCompat.checkSelfPermission(
        reactApplicationContext,
        Manifest.permission.RECORD_AUDIO
      ) != PackageManager.PERMISSION_GRANTED
    ) {
      ActivityCompat.requestPermissions(
        currentActivity!!,
        arrayOf(Manifest.permission.RECORD_AUDIO),
        1
      )
    }
  }

  override fun stop() {
    isCapturing = false
    audioRecord?.stop()
    audioRecord?.release()
    audioRecord = null
//    scope.cancel()
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

  private fun detectPitch(buffer: FloatArray, sampleRate: Float): Float {
    val tauMax = buffer.size / 2
    val d = FloatArray(tauMax)
    val cmndf = FloatArray(tauMax)

    d[0] = 0f
    for (tau in 1 until tauMax) {
      var sum = 0f
      for (j in 0 until buffer.size - tau) {
        val diff = buffer[j] - buffer[j + tau]
        sum += diff * diff
      }
      d[tau] = sum
    }

    cmndf[0] = 1f
    var runningSum = 0f
    for (tau in 1 until tauMax) {
      runningSum += d[tau]
      cmndf[tau] = if (runningSum > 0) d[tau] * tau / runningSum else 1f
    }

    val threshold = 0.15f
    var tauEstimate = -1

    for (tau in 1 until tauMax) {
      if (cmndf[tau] < threshold) {
        var localTau = tau
        while (localTau + 1 < tauMax && cmndf[localTau + 1] < cmndf[localTau]) {
          localTau++
        }
        tauEstimate = localTau
        break
      }
    }

    if (tauEstimate < 0) {
      var minCMND = Float.MAX_VALUE
      for (tau in 1 until tauMax) {
        if (cmndf[tau] < minCMND) {
          minCMND = cmndf[tau]
          tauEstimate = tau
        }
      }
    }

    return if (tauEstimate > 0) sampleRate / tauEstimate else 0f
  }

  private fun onFrequencyDetected(frequency: Double) {
    reactApplicationContext.emitDeviceEvent("onFrequencyDetected", frequency)
  }

  override fun setConfiguration(fftConfiguration: ReadableMap?) {
    if (fftConfiguration != null) {
      highPassHz = fftConfiguration.getDouble("highPassHz").toFloat()
      lowPassHz = fftConfiguration.getDouble("lowPassHz").toFloat()
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
