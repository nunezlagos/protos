# Voice loop natural para Protos — Design

## Decisions

| Decisión | Opción | Alternativas | Razón |
|---|---|---|---|
| Audio preprocessing | WebRTC AudioProcessingModule | RNNoise, SpeexDSP, silero | Incluye AEC+NS+AGC+VAD en un bundle, corre en CPU, liviano, battle-tested |
| VAD | Integrado en AudioProcessingModule | webrtcvad aparte | El módulo de WebRTC ya incluye VAD propio; no duplicar |
| Concurrencia | asyncio + threading | asyncio puro, threads puro | sounddevice usa callback nativo; AudioProcessingModule procesa en bloque |
| Streaming TTS | Kokoro.speak_stream() + sd.play() | Esperar respuesta completa | Evita latencia acumulada |
| History | Sliding window en memoria (20) | Resumen periódico con Gemini | Simple, sin dependencias extra |
| Referencia AEC | Buffer compartido entre TTS y AudioPreprocessor | Loopback de dispositivo | sounddevice no expone loopback; buffer compartido es determinístico |

## Data Flow

```
                         ┌─ sounddevice.OutputStream ← Kokoro.speak_stream()
                         │        (playback)                  ↑
                         │                                    │ audio chunks
                         │   buffer compartido (referencia)───┘
                         ▼
User habla → mic → sounddevice.InputStream
                         ↓ frames 16kHz mono
                  WebRTC AudioProcessingModule
                         ├─ AEC: resta referencia de playback
                         ├─ NoiseSuppression: reduce ruido fondo
                         ├─ AGC: normaliza volumen
                         └─ VAD: speech_start / speech_end
                              ↓ audio limpio + eventos VAD
                         ┌─ si VAD=speech:
                         │    → WhisperSTT.transcribe()
                         │    → HistoryWindow.append(user, text)
                         │    → GeminiClient.ask(prompt con historial)
                         │    → KokoroTTS.speak_stream(response)
                         │    → sounddevice.play() chunks progresivos
                         │    → loop (barge-in monitorea por AEC+VAD)
                         └─ si VAD=noise/silence:
                              → descartar, seguir escuchando
```

## TDD Plan

1. AudioPreprocessor test: input con eco sintético → assert output sin eco
2. AudioPreprocessor test: input con ruido → assert noise suppression activo
3. VAD test: audios pre-grabados → assert speech/no-speech
4. HistoryWindow test: append N items → assert sliding
5. StreamingTTS test: consume stream → assert chunks progresivos
6. Barge-in test: playback + simular voz con AEC → assert TTS stop sin falsos positivos
7. Integración: loop completo con audios sintéticos

## Risk Mitigation

- AEC sin loopback real: buffer compartido es aproximación válida para un solo proceso
- Feedback loop residual: ajustar aggressiveness de AEC + umbral de VAD durante playback
- Crecimiento tokens: límite duro 20 exchanges
