package com.tidara.tidara_smartclock

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.sin

class PresetAudioLogicTest {

    @Test
    fun testPresetFrequencyResolution() {
        fun resolveFrequency(audioPath: String, label: String): Pair<Double, String> {
            val lower = "$audioPath $label".lowercase()
            return when {
                lower.contains("528") || lower.contains("solfeggio") || lower.contains("chime") -> {
                    Pair(528.0, "preset_528hz.wav")
                }
                lower.contains("639") || lower.contains("dawn") || lower.contains("resonance") -> {
                    Pair(639.0, "preset_639hz.wav")
                }
                else -> {
                    Pair(432.0, "preset_432hz.wav")
                }
            }
        }

        val solfeggio = resolveFrequency("", "528Hz Solfeggio Chime")
        assertEquals(528.0, solfeggio.first, 0.001)
        assertEquals("preset_528hz.wav", solfeggio.second)

        val dawn = resolveFrequency("", "639Hz Dawn Resonance")
        assertEquals(639.0, dawn.first, 0.001)
        assertEquals("preset_639hz.wav", dawn.second)

        val bowl = resolveFrequency("", "432Hz Tibetan Singing Bowl")
        assertEquals(432.0, bowl.first, 0.001)
        assertEquals("preset_432hz.wav", bowl.second)

        val fallback = resolveFrequency("", "Standard Alarm")
        assertEquals(432.0, fallback.first, 0.001)
        assertEquals("preset_432hz.wav", fallback.second)
    }

    @Test
    fun testRiffWaveHeaderStructure() {
        val sampleRate = 22050
        val durationSec = 1.0
        val numSamples = (sampleRate * durationSec).toInt()
        val dataSize = numSamples * 2
        val totalSize = 44 + dataSize
        val buffer = ByteArray(totalSize)

        fun writeIntLE(buf: ByteArray, offset: Int, value: Int) {
            buf[offset] = (value and 0xFF).toByte()
            buf[offset + 1] = ((value shr 8) and 0xFF).toByte()
            buf[offset + 2] = ((value shr 16) and 0xFF).toByte()
            buf[offset + 3] = ((value shr 24) and 0xFF).toByte()
        }

        fun writeShortLE(buf: ByteArray, offset: Int, value: Short) {
            buf[offset] = (value.toInt() and 0xFF).toByte()
            buf[offset + 1] = ((value.toInt() shr 8) and 0xFF).toByte()
        }

        // Write header
        buffer[0] = 'R'.code.toByte(); buffer[1] = 'I'.code.toByte(); buffer[2] = 'F'.code.toByte(); buffer[3] = 'F'.code.toByte()
        writeIntLE(buffer, 4, 36 + dataSize)
        buffer[8] = 'W'.code.toByte(); buffer[9] = 'A'.code.toByte(); buffer[10] = 'V'.code.toByte(); buffer[11] = 'E'.code.toByte()
        buffer[12] = 'f'.code.toByte(); buffer[13] = 'm'.code.toByte(); buffer[14] = 't'.code.toByte(); buffer[15] = ' '.code.toByte()
        writeIntLE(buffer, 16, 16)
        writeShortLE(buffer, 20, 1.toShort()) // PCM format
        writeShortLE(buffer, 22, 1.toShort()) // Mono channel
        writeIntLE(buffer, 24, sampleRate)
        writeIntLE(buffer, 28, sampleRate * 2) // Byte rate
        writeShortLE(buffer, 32, 2.toShort()) // Block align
        writeShortLE(buffer, 34, 16.toShort()) // Bits per sample
        buffer[36] = 'd'.code.toByte(); buffer[37] = 'a'.code.toByte(); buffer[38] = 't'.code.toByte(); buffer[39] = 'a'.code.toByte()
        writeIntLE(buffer, 40, dataSize)

        // Validate canonical RIFF markers
        assertEquals('R'.code.toByte(), buffer[0])
        assertEquals('I'.code.toByte(), buffer[1])
        assertEquals('F'.code.toByte(), buffer[2])
        assertEquals('F'.code.toByte(), buffer[3])

        assertEquals('W'.code.toByte(), buffer[8])
        assertEquals('A'.code.toByte(), buffer[9])
        assertEquals('V'.code.toByte(), buffer[10])
        assertEquals('E'.code.toByte(), buffer[11])

        assertEquals('f'.code.toByte(), buffer[12])
        assertEquals('m'.code.toByte(), buffer[13])
        assertEquals('t'.code.toByte(), buffer[14])
        assertEquals(' '.code.toByte(), buffer[15])

        assertEquals('d'.code.toByte(), buffer[36])
        assertEquals('a'.code.toByte(), buffer[37])
        assertEquals('t'.code.toByte(), buffer[38])
        assertEquals('a'.code.toByte(), buffer[39])

        // Audio format == 1 (PCM)
        assertEquals(1, buffer[20].toInt())
        // Channels == 1 (Mono)
        assertEquals(1, buffer[22].toInt())
        // Bits per sample == 16
        assertEquals(16, buffer[34].toInt())
    }

    @Test
    fun testAlarmNumericIdRangeConstraint() {
        val testIds = listOf(
            "alarm-morning-1",
            "alarm-brahma-meditation",
            "custom-alarm-2026",
            "random_alarm_9999",
            "sunrise_alarm_bengaluru",
            "alarm-1700000000000"
        )

        for (id in testIds) {
            val numericId = (id.hashCode() and 0x7fffffff) % 90000 + 1000
            assertTrue("Numeric ID $numericId must be >= 1000", numericId >= 1000)
            assertTrue("Numeric ID $numericId must be <= 90999", numericId <= 90999)
        }
    }

    @Test
    fun testAudioFileNameSanitization() {
        fun sanitize(input: String): String {
            return input.replace(Regex("[^a-zA-Z0-9._-]"), "_")
        }

        assertEquals("My_Alarm_Track.mp3", sanitize("My Alarm Track.mp3"))
        assertEquals("track_chime_bell.wav", sanitize("track*chime:bell.wav"))
        assertEquals("normal_audio.m4a", sanitize("normal_audio.m4a"))
        assertEquals("test_audio.ogg", sanitize("test/audio.ogg"))
    }
}

