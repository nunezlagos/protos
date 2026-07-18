# Voice loop natural para Protos

## Why

El MVP actual usa detección RMS threshold: graba hasta N segundos de silencio, corta, transcribe, manda a Gemini, espera respuesta completa, la reproduce. Esto genera:
- Cortes abruptos porque RMS no distingue voz de ruido
- Sin historial: cada frase es independiente, Gemini no sabe qué se dijo antes
- Sin streaming TTS: hay que esperar la respuesta entera antes de escuchar algo
- Sin barge-in: no se puede interrumpir
- Sin AEC: el mic escucha lo que sale del parlante, feedback loop constante

Para que la conversación se sienta natural, necesitamos preprocesamiento de audio en tiempo real (AEC + noise suppression + AGC) más VAD, barge-in, streaming TTS e historial.

## Scope

**Incluye:**
- WebRTC AudioProcessing Module: AEC (echo cancellation), noise suppression, AGC (gain control), VAD
- Barge-in con AEC: el mic monitorea activamente pero sin escucharse a sí mismo
- Streaming asíncrono del TTS con Kokoro (speak_stream) + reproducción inmediata
- Sliding window de historial conversacional (últimos 20 exchanges)

**No incluye:**
- Turno predictivo (que Gemini decida cuándo responder)
- Wake word / push-to-talk
- Voz expresiva con emociones
- UI visual

## Approach

Reestructurar apps/runtime/src/runtime/ en capas asíncronas con asyncio:

1. **AudioPreprocessor:** envoltura de `webrtc-audio-processing` (AudioProcessingModule). El audio crudo del mic pasa por AEC (referencia: loopback de lo que se está reproduciendo) + noise suppression + AGC + VAD. La salida es audio limpio + señal de speech activity.

2. **BargeInLayer:** mientras Kokoro reproduce audio, el AudioPreprocessor sigue procesando el mic con AEC activo. Si VAD detecta voz del usuario (después de cancelar el eco), frenamos TTS y arrancamos nuevo turno.

3. **HistoryWindow:** lista de {role, text}. Sliding window de últimos 20 exchanges. Se inyecta como contexto en cada llamada a Gemini.

4. **StreamingTTS:** Kokoro.speak_stream() → generador asíncrono → sounddevice reproduciendo chunks en vivo.

## Risks

- **AEC necesita referencia de loopback:** hay que capturar lo que se reproduce para cancelarlo. sounddevice no da acceso directo al output, habrá que usar un buffer compartido entre TTS y AudioPreprocessor.
- **webrtcvad + AEC:** el módulo de WebRTC incluye VAD propio; no necesitamos webrtcvad aparte.
- **HistoryWindow** crece tokens lineales. Mitigación: límite de 20 exchanges.

## Testing

Por capa:
- AudioPreprocessor: grabaciones con eco simulada → assert AEC elimina el eco
- VAD: grabaciones predefinidas (voz limpia, ruido, silencio)
- Barge-in: TTS reproduciéndose + simulación de entrada de mic con AEC activo
- HistoryWindow: append/sliding unit test
- StreamingTTS: chunks progresivos
- Integración: loop completo con audios sintéticos
