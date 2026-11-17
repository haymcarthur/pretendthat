// A tiny C API over Signalsmith Stretch (MIT, vendor/) for Nutmeg's pitch raise
// (thinking/decisions/2026-11-17-voice-pitch-build.md). Mono float samples, duration unchanged.
// Not thread-safe: one shifter per stream.
#ifndef SIGNALSMITH_SHIFT_H
#define SIGNALSMITH_SHIFT_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct PTShifter PTShifter;

/// A mono shifter: `blockSamples` STFT block, `intervalSamples` hop.
PTShifter *pt_shifter_create(int blockSamples, int intervalSamples);
void pt_shifter_destroy(PTShifter *s);
/// Pitch in semitones. `formantSemitones` < -100 means formants move with the pitch (no formant processing);
/// otherwise formants end up `formantSemitones` away from the INPUT's formants (Signalsmith's compensatePitch mode).
void pt_shifter_set(PTShifter *s, float semitones, float formantSemitones);
int pt_shifter_input_latency(const PTShifter *s);
int pt_shifter_output_latency(const PTShifter *s);
/// Clears all state (a new stream starts fresh).
void pt_shifter_reset(PTShifter *s);
/// Pre-roll input (no output), so the next `process` output lines up with the input.
void pt_shifter_seek(PTShifter *s, const float *input, int count);
/// `count` samples in, `count` samples out.
void pt_shifter_process(PTShifter *s, const float *input, float *output, int count);
/// The rest of the output (after the last input), `count` samples.
void pt_shifter_flush(PTShifter *s, float *output, int count);

#ifdef __cplusplus
}
#endif
#endif
