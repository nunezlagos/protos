# Voice loop natural

#### Scenario: Echo cancelled during playback

- **Given** the assistant is speaking a response through the speaker
- **When** the user speaks at the same time
- **Then** the AEC removes the playback signal from the mic input
- **And** the VAD detects the user speech correctly
- **And** the barge-in triggers without false positive from the playback

#### Scenario: Background noise suppressed

- **Given** a recording with keyboard noise and fan hum
- **When** AudioPreprocessor processes the audio
- **Then** the output has at least 10dB less noise floor
- **And** Whisper transcription quality is preserved or improved

#### Scenario: Gain normalized across speakers

- **Given** two recordings: one quiet, one loud
- **When** AGC processes both
- **Then** the RMS levels are within 3dB of each other

#### Scenario: Speech detected correctly

- **Given** a clean voice recording of 3 seconds
- **When** VAD processes the audio
- **Then** it returns speech_start and speech_end within 200ms of actual boundaries

#### Scenario: Silence ignored

- **Given** a recording of background noise only
- **When** VAD processes the audio
- **Then** it returns no speech detected

#### Scenario: User interrupts during TTS playback

- **Given** the assistant is speaking a response
- **When** the user starts speaking
- **Then** TTS playback stops within 500ms
- **And** a new recording turn starts immediately

#### Scenario: Context preserved across turns

- **Given** a conversation of 3 user-assistant exchanges
- **When** the next Gemini call is made
- **Then** the prompt includes all 3 previous exchanges

#### Scenario: Window limited to 20 exchanges

- **Given** a conversation of 25 exchanges
- **When** the Gemini call is made
- **Then** only the last 20 exchanges are included

#### Scenario: Audio plays progressively

- **Given** a long text response
- **When** Kokoro generates the stream
- **Then** sounddevice starts playback before the full response is generated

#### Scenario: Full voice loop

- **Given** a recorded user query
- **When** the loop runs
- **Then** AudioPreprocessor cleans the audio (AEC + NS + AGC + VAD)
- **And** Whisper transcribes correctly
- **And** Gemini responds in Spanish with conversation history
- **And** Kokoro streams the response
- **And** playback completes without echo artifacts
