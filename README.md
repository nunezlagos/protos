# Protos — Voice runtime

Natural voice interaction: STT (Whisper) → LLM (Gemini) → TTS (Kokoro) with barge-in.

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/nunezlagos/protos/main/install.sh | bash
```

Then copy and edit the env config:

```bash
cp .env.example .env
# edit .env with your Gemini API key
```

## Usage

```bash
make install-all   # install runtime dependencies
make run           # start the voice loop
```

## Layout

```
apps/runtime/   — voice loop application
libs/kokoro/    — Kokoro TTS wrapper
scripts/        — installer scripts
instructions/   — system prompts
```
