// C wrapper over Signalsmith Stretch (MIT, vendor/signalsmith-stretch) + Signalsmith Linear (MIT,
// vendor/signalsmith-linear). Built with optimization in every configuration (Package.swift): Debug is ~10x slower.
#include "SignalsmithShift.h"
#include "vendor/signalsmith-stretch/signalsmith-stretch.h"

struct PTShifter {
	signalsmith::stretch::SignalsmithStretch<float> stretch;
};

extern "C" {

PTShifter *pt_shifter_create(int blockSamples, int intervalSamples) {
	auto *s = new PTShifter();
	s->stretch.configure(1, blockSamples, intervalSamples);
	return s;
}

void pt_shifter_destroy(PTShifter *s) { delete s; }

void pt_shifter_set(PTShifter *s, float semitones, float formantSemitones) {
	s->stretch.setTransposeSemitones(semitones);
	if (formantSemitones < -100) {
		s->stretch.setFormantFactor(1, false);   // formants move with the pitch (plain shift, no formant processing)
	} else {
		s->stretch.setFormantSemitones(formantSemitones, true);
		s->stretch.setFormantBase(0);   // detect the pitch for the formant analysis
	}
}

int pt_shifter_input_latency(const PTShifter *s) { return s->stretch.inputLatency(); }
int pt_shifter_output_latency(const PTShifter *s) { return s->stretch.outputLatency(); }

void pt_shifter_reset(PTShifter *s) { s->stretch.reset(); }

void pt_shifter_seek(PTShifter *s, const float *input, int count) {
	const float *in[1] = {input};
	s->stretch.seek(in, count, 1.0);
}

void pt_shifter_process(PTShifter *s, const float *input, float *output, int count) {
	const float *in[1] = {input};
	float *out[1] = {output};
	s->stretch.process(in, count, out, count);
}

void pt_shifter_flush(PTShifter *s, float *output, int count) {
	float *out[1] = {output};
	s->stretch.flush(out, count);
}

}
