# Voice loop natural — Tasks

## Implementacion

- [ ] VADLayer: wrapper de webrtcvad con sounddevice.InputStream async
- [ ] BargeInLayer: monitoreo paralelo de mic durante TTS playback
- [ ] HistoryWindow: sliding window de exchanges + formateo para Gemini
- [ ] StreamingTTS: Kokoro.speak_stream() con sounddevice.write() progresivo
- [ ] main.py: loop reescrito con las 4 capas y asyncio

## Tests

- [ ] Test VAD: audio pre-grabado con speech (assert deteccion)
- [ ] Test VAD: audio pre-grabado sin speech (assert no deteccion)
- [ ] Test HistoryWindow: append N items, assert ventana mantiene max
- [ ] Test HistoryWindow: formateo para Gemini (assert estructura esperada)
- [ ] Test StreamingTTS: assert chunks progresivos
- [ ] Test BargeIn: simular voz durante playback, assert interrupcion

## Documentacion

- [ ] Actualizar state.yaml a implemented
