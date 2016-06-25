/*
Entropia SynthDefs

Naming synths:
\pia__<t>__<name>, where:
<t> - type of the synth, where:
    g - granular (\bufnum points to a buffer with a sound file loaded)
    e - electronic (if there is a \bufnum it can point to a buffer with a scale)
    p - percussion
    s - spatialization
    r - recording
    u - utilities
<name> - something meaninful
*/

// Generators.
//
// - every time a Gen synth is created, its output (mono!) is sent to a chosen bus,
// which feeds into automatically created Spatializing synth.
//
// - some params such as azimuth and distance are sent to both Gen synths, where they
// control parameters of audio, and Spatializing synths, where they determine a
// position and span of the Gen output.


// GRANULAR SYNTHS
//
// ...

// ELECTRONIC SYNTHS
//
// ...
SynthDef(\pia__e__humm, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=0.5, velocity=0.5,
        offset=36, cutoff=0;
    var note, in, out, signal;
    // Conversion.
    note = (DegreeToKey.kr(bufnum, az.linlin(0, 1, 0, 15), 12, 1, offset)
        + LFNoise1.kr([3, 3], 0.04)).midicps;    // add some low freq stereo detuning
    // Synthesis.
    in = LFSaw.ar((1..5) * note, abs(velocity * 2), velocity)
         + Impulse.ar((0..4) + SinOsc.ar((4..8) * note).exprange(0.3, 300));
    in = Mix.ar(in) * amp * 0.1;
    signal = RLPF.ar(in, LinLin.kr(velocity, 0, 1, 80, 30).midicps, velocity);
    // Envelope.
    out = signal * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\pia__e__hammond, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=0.5, velocity=0.5,
        offset=44, cutoff=0;
    var freq, scale, scaleBase, harmonics,
        env, signal, out;
    scaleBase = [0, 12, 17, 24, 29, 32];
    scale = (scaleBase - scaleBase.last)[1..scaleBase.lastIndex-1]
        ++ scaleBase
        ++ (scaleBase[1] + scaleBase.maxItem + scaleBase);
    freq = (scale + offset).clip(0, 127);
    harmonics = Harmonics.new(scale.size).formant(4, 9);
    signal = Mix.ar(SinOsc.ar(freq.midicps, 0, harmonics) * 0.112) * amp;
    out = signal * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


// DRUMS AND PERCUSSION
// (Warning! Different enveloping.)
//
// ...

// SPATIALIZERS
//
// - spatializer has no attack, but longer \rel to ensure that it will be released after corresponding Gen synth,
//   since \rel param is sent to both Gen synth and Spatializer.
//

// XXX - DELETE AFTER TESTING
SynthDef(\pia__s__stereo, {
    arg inbus=20, outbus=0, gate=1, rel=1,
        azimuth=0, elevation=0, elevClip=0.01pi, distance=0, depth=5;
    var in, signal, out, room, mix, dist;
    dist = distance.linlin(0, 2.sqrt, 0.01, depth);
    mix = dist.linexp(0.01, depth, 0.1, 0.8);
    room = dist.linexp(0.01, depth, 0.2, 1);
    in = In.ar(inbus, 1);
    in = RLPF.ar(
        FreeVerb.ar(in, mix, room, 0.2),
        distance.linlin(0.01, depth, 10000, 1000),
        0.5);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    out = Pan2.ar(signal, azimuth/1pi, distance.linlin(0, 2.sqrt, 1, 0.01));
    Out.ar(outbus, out);
}).send(s);


SynthDef(\pia__s__ambisonic2, {
    arg inbus=20, outbus=0, gate=1, rel=1,
        azimuth=0, elevation=0, elevClip=0.01pi, distance=0, depth=5;
    var w, x, y, z, r, s, t, u, v,
        speakerAzim=[-0.25pi, -0.75pi], speakerElev = 0,
        speakerDist=[1, 1], maxDist=2.2, scaleFlag=1,
        in, signal, out, room, mix;
    maxDist = speakerDist.maxItem;
    distance = distance.linlin(0, 2.sqrt, 0.01, depth);
    mix = distance.linexp(0.01, depth, 0.1, 0.8);
    room = distance.linexp(0.01, depth, 0.2, 1);
    in = In.ar(inbus, 1);
    in = RLPF.ar(
        FreeVerb.ar(in, mix, room, 0.2),
        distance.linlin(0.01, depth, 10000, 1000),
        0.5);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


// RECORDING AND AUDIO
//
SynthDef(\pia__r__rec1, { // mono recording
    arg inbus, bufnum=0, amp=1;
    DiskOut.ar(bufnum, Limiter.ar(amp * InFeedback.ar(inbus, 1), 0.99, 0.01) );
}).send(s);


SynthDef(\pia__r__rec2, { // stereo recording
    arg inbus, bufnum=0, amp=1;
    DiskOut.ar(bufnum, Limiter.ar(amp * InFeedback.ar(inbus, 2), 0.99, 0.01) );
}).send(s);


SynthDef(\pia__r__buffloop, { // continuous recording into buffer
    arg bufnum, busnum=0, volIn=0.8, loop=1, dur=1, gate=0;
    RecordBuf.ar(
        InFeedback.ar(busnum)
        * EnvGen.kr(
            Env.linen(0.1, dur-0.2, 0.1, volIn, \welch),
            gate: Impulse.kr(gate.reciprocal)
        ),
        bufnum, 0, volIn, 0, 1, loop, 1
    );
}).send(s);


SynthDef(\pia__r__authro, { // audio-through
    arg bufnum=0, inbus=0, outbus=0,
        amp=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=0.5, velocity=0.5;
    var in, out, signal, ds;
    // Conversion.
    ds = distance/3.44;
    // Synthesis.
    in = InFeedback.ar(inbus, 1);
    signal = RLPF.ar(
        DelayL.ar(FreeVerb.ar(in, distance.clip(0.01, 1), ds, 0.2), 0.3, ds),
        distance.linlin(0, 2.sqrt, 10000, 1000), 0.5);
    // Envelope.
    out = signal * EnvGen.kr(Env.adsr(att, 0.1, amp, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).send(s);


// MODULATORS
//
SynthDef(\pia__k__sin, {
    arg outbus=0, freq=440, phase=0, mul=1, add=0, mod_mul=0.45, mod_add=0.55, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * SinOsc.kr(LFNoise0.kr(freq, mod_mul, mod_add), LFDClipNoise.kr(freq), mul, add);
    Out.kr(outbus, out);
}).add;

SynthDef(\pia__k__saw, {
    arg outbus=0, freq=440, mul=1, add=0, mod_mul=0.45, mod_add=0.55, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * Saw.kr(LFNoise0.kr(freq, mod_mul, mod_add), mul, add);
    Out.kr(outbus, Saw.kr(freq, mul, add));
}).add;

SynthDef(\pia__k__tri, {
    arg freq=440, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFTri.kr(freq, phase, mul, add);
    Out.kr(outbus, out);
}).add;

// clip noise
SynthDef(\pia__k__clipnoise, {
    arg freq=1, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFDClipNoise.kr(freq, mul, add);
    Out.kr(outbus, out);
}).add;

// step noise
SynthDef(\pia__k__lfnoise0, {
    arg freq=1, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFDNoise0.kr(freq, mul, add);
    Out.kr(outbus, out);
}).add;

SynthDef(\pia__k__lfnoise1, {
    arg freq=1, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFNoise1.kr(freq, mul, add);
    Out.kr(outbus, out );
}).add;

SynthDef(\pia__k__lfnoise2, {
    arg freq=1, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFNoise2.kr(freq).clip2 * mul + add;
    Out.kr(outbus, out );
}).add;

SynthDef(\pia__k__stepnoise, {
    arg freq=1, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * TWChoose.kr(
        Dust.ar(1),
        [LFNoise0.kr(freq, mul, add), LFNoise1.kr(freq, mul, add), LFNoise2.kr(freq).clip2 * mul + add],
        [0.1, 0.4, 0.5]
    );
    Out.kr(outbus, out );
}).add;


// UTILITIES
//
SynthDef(\pia__u__grain, { //individual grain (can only be sent to audio in).
    arg bufnum=0, busnum=0, amp=1, att=1, rel=1, ca=3, cr= -3,
    pos=0.0, rate=1, dur=0.1;
    var in, out;
    // Synthesis.
    in = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum) * rate, 1, BufFrames.ir(bufnum) * pos, 0);
    // Envelope.
    out = in * (EnvGen.kr(Env.perc(0.01, dur), doneAction:2) - 0.001);
    Out.ar(busnum, out);
}).send(s);

// sample player (can only be sent to audio in).
SynthDef(\pia__u__play, {
    arg bufnum=0, busnum=0,
        amp=1, att=1, rel=1, gate=1, ca=3, cr= -3,
        pos=0.0, rate=1, dur=0.1;
    var in, out;
    // Synthesis.
    in = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum) * rate, 1, BufFrames.ir(bufnum) * pos, 1);
    // Envelope.
    out = in * EnvGen.kr(Env.adsr(att, 0.1, amp, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(busnum, out);
}).send(s);

// Stereo mix-node: LPF input, send summary to outbus
SynthDef(\pia__u__mixNode2, {
    arg inbus=0, outbus=2, gate=1;
    var env, in, out;
    in = Limiter.ar(LPF.ar(InFeedback.ar(inbus, 2), 200) * 0.7);
    env = EnvGen.kr(Env.asr(0.1, 1, 0.5, [3, -3]), gate: gate, doneAction:2);
    out = Mix.ar(in * env);
    Out.ar(outbus, out);
}).send(s);

// Quad mix-node: LPF input, send summary to outbus
SynthDef(\pia__u__mixNode4, {
    arg inbus=0, outbus=4, gate=1;
    var env, in, out;
    in = Limiter.ar(LPF.ar(InFeedback.ar(inbus, 4), 200) * 0.7);
    env = EnvGen.kr(Env.asr(0.1, 1, 0.5, [3, -3]), gate: gate, doneAction:2);
    out = Mix.ar(in * env);
    Out.ar(outbus, out);
}).send(s);

// Pent mix-node: LPF input, send summary to outbus
SynthDef(\pia__u__mixNode5, {
    arg inbus=0, outbus=5, gate=1;
    var env, in, out;
    in = Limiter.ar(LPF.ar(InFeedback.ar(inbus, 5), 200) * 0.7);
    env = EnvGen.kr(Env.asr(0.1, 1, 0.5, [3, -3]), gate: gate, doneAction:2);
    out = Mix.ar(in * env);
    Out.ar(outbus, out);
}).send(s);

// Hex mix-node: LPF input, send summary to outbus
SynthDef(\pia__u__mixNode6, {
    arg inbus=0, outbus=6, gate=1;
    var env, in, out;
    in = Limiter.ar(LPF.ar(InFeedback.ar(inbus, 6), 200) * 0.7);
    env = EnvGen.kr(Env.asr(0.1, 1, 0.5, [3, -3]), gate: gate, doneAction:2);
    out = Mix.ar(in * env);
    Out.ar(outbus, out);
}).send(s);

// Oct mix-node: LPF input, send summary to outbus
SynthDef(\pia__u__mixNode8, {
    arg inbus=0, outbus=8, gate=1;
    var env, in, out;
    in = Limiter.ar(LPF.ar(InFeedback.ar(inbus, 8), 200) * 0.7);
    env = EnvGen.kr(Env.asr(0.1, 1, 0.5, [3, -3]), gate: gate, doneAction:2);
    out = Mix.ar(in * env);
    Out.ar(outbus, out);
}).send(s);
