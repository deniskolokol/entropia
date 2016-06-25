// Matrix Synth (work-title)
// module: SynthDefs
// ---------------
// Naming synths:
// \ms__<t>__<name>, where:
//     <t> - type of the synth, where:
//         a - .ar (generator - .ar out)
//         k - .kr (modulator - .kr out)
//         p - processor (effect - .ar in and out)
//         s - spatialization (.ar in and out)
//         r - recording (.ar in)
//         u - utilities (various)
//     <name> - something meaninful
//
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
SynthDef(\ms__a__loop, {
    arg bufnum=0, inbus=30, route=20,
        ax=0, ay=0, az=0, velocity=10, distance=0.5,
        pos=0, amp=1, attenuate=1, master=1, gate=1, rate=1, att=1, rel=1, ca=3, cr= -3;
    var in, signal, out, ds;
    ds = distance/3.44;
    in = PlayBuf.ar(1, bufnum,
        // slight disturbances of rate
        BufRateScale.kr(bufnum) * (rate + LFNoise1.kr(LFNoise1.ar(1.4, 1, 1.6), 0.15)),
        Impulse.ar(BufDur.kr(bufnum).reciprocal), BufFrames.ir(bufnum) * pos);
    signal = in * amp * attenuate;
    // Envelope.
    out = signal * master * EnvGen.kr(Env.asr(att, 1, rel, [ca, cr]), gate: gate, doneAction:2);
    Out.ar(route, out)
}).send(s);


//individual grain
SynthDef(\ms__p__grain, {
    arg bufnum=0, inbus=30, route=20,
        amp=1, master=1, att=1, rel=1, ca=3, cr= -3,
        pos=0.0, rate=1, dur=0.1, lag=0;
    var in, out;
    // Synthesis.
    in = PlayBuf.ar(1, bufnum,
        Lag.ar(K2A.ar(BufRateScale.kr(bufnum) * rate), lag),
        1, BufFrames.ir(bufnum) * pos, 0);
    // Envelope.
    out = in * amp * master * (EnvGen.kr(Env.perc(0.01, dur), doneAction:2) - 0.001);
    Out.ar(route, out);
}).send(s);


// ELECTRONIC SYNTHS
//
SynthDef(\ms__a__sawy, {
    arg bufnum=0, inbus=30, route=20,
        amp=1, attenuate=0.05, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        azimuth=0, distance=0.5, elevation=0, velocity=0.5,
        offset=36, cutoff=1000, rq=0.5, scope=12;
    var note, in, out, signal;
    // Conversion.
    note = DegreeToKey.kr(bufnum, elevation.linlin(-0.5pi, 0.5pi, 0, scope), 12, 1, offset);
    // Synthesis.
    in = Mix.fill(8, {LFSaw.ar((note + 0.1.rand2).midicps, 0, amp) * attenuate});
    // filter
    signal = RLPF.ar(RLPF.ar(in, cutoff, rq), cutoff, rq);
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(route, out);
}).add;

SynthDef(\ms__a__electro, {
    arg bufnum=0, inbus=30, route=20,
        amp=1, attenuate=0.5, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        azimuth=0, distance=0.5, elevation=0, velocity=0.5,
        offset=36, cutoff=1000, rq=0.5, scope=12;
    var note, in, out, signal;
    // Conversion.
    note = (
        DegreeToKey.kr(bufnum, elevation.linlin(-0.5pi, 0.5pi, 0, scope), 12, 1, offset)
        + LFNoise1.kr([3, 3], 0.04) // add some low freq stereo detuning
    ).midicps;
    // Synthesis.
    in = LFSaw.ar((1..5) * note, abs(velocity * 2), velocity)
         + Impulse.ar((0..4) + SinOsc.ar((4..8) * note).exprange(0.3, 300));
    in = Mix.ar(in) * amp * attenuate;
    // filter
    signal = RLPF.ar(RLPF.ar(in, cutoff, rq), cutoff, rq);
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(route, out);
}).add;

SynthDef(\ms__a__wind, {
    arg bufnum=0, inbus=30, route=20,
        amp=1, attenuate=0.05, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        azimuth=0, distance=0.5, elevation=0, velocity=0.5,
        offset=36, cutoff=1000, rq=0.5, scope=12;
	var in, out, signal;
    var fbase, shift;
    // Conversion.
    fbase = distance.linexp(0, 1, 10, 40);
    shift = ((velocity * 30) ** 3).lag(0.01);
    // Synthesis.
    in = Formlet.ar(
        WhiteNoise.ar(SinOsc.ar(fbase, shift, 0.5, 1)).min(1) + SinOsc.ar(fbase, shift),
        LFNoise1.ar(TRand.kr(trig:Delay2.kr(Dust.kr(0.5))), 2450, 2550), 0.01, 0.1
    ).softclip;
    in = [in, DelayN.ar(in, 0.04, 0.4)];
    in = Mix.fill(4, {AllpassN.ar(in, 0.5, [0.5.rand, 0.5.rand], 4, amp) * attenuate});
    // filter
    signal = RLPF.ar(RLPF.ar(in, cutoff, rq), cutoff, rq);
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(route, out);
}).send(s);


// SPATIALIZERS
//
// - spatializer has no attack, but longer \rel to ensure that it will be released after corresponding Gen synth,
//   since \rel param is sent to both Gen synth and Spatializer.
//

SynthDef(\ms__s__ambisonic2, {
    arg route=20, outbus=0, gate=1, rel=1,
        azimuth=0, elevation=0, elevClip=0.01pi, distance=0, depth=5,
        speakerAzim= #[-0.25pi, -0.75pi], speakerElev= #[0, 0], speakerDist= #[2, 2], maxDist=2;
    var w, x, y, z, r, s, t, u, v, scaleFlag=1,
        in, signal, out, room, mix;
    distance = distance.linlin(0, 2.sqrt, 0.01, depth);
    mix = distance.linexp(0.01, depth, 0.1, 0.8);
    room = distance.linexp(0.01, depth, 0.2, 1);
    in = In.ar(route, 1);
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


SynthDef(\ms__s__ambisonic4, {
    arg route=20, outbus=0, gate=1, rel=1,
        azimuth=0, elevation=0, elevClip=0.01pi, distance=0, depth=5,
        speakerAzim= #[-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= #[0, 0, 0, 0],
        speakerDist= #[2, 2, 2, 2], maxDist=2;
    var w, x, y, z, r, s, t, u, v, scaleFlag=1,
        in, signal, out, room, mix;
    distance = distance.linlin(0, 2.sqrt, 0.01, depth);
    mix = distance.linexp(0.01, depth, 0.1, 0.8);
    room = distance.linexp(0.01, depth, 0.2, 1);
    in = In.ar(route, 1);
    in = RLPF.ar(
        FreeVerb.ar(in, mix, room, 0.2),
        distance.linlin(0.5, depth, 10000, 1000),
    0.5);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
    azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\ms__s__ambisonic6, {
    arg route=20, outbus=0, gate=1, rel=1,
        azimuth=0, elevation=0, elevClip=0.01pi, distance=0, depth=5,
        speakerAzim= #[-0.25pi, -0.5pi, -0.75pi, 0.75pi, 0.5pi, 0.25pi], speakerElev=[0, 0, 0, 0, 0, 0],
        speakerDist= #[2, 2, 2, 2, 2, 2], maxDist=2;
    var w, x, y, z, r, s, t, u, v, scaleFlag=1,
        in, signal, out, room, mix;
    distance = distance.linlin(0, 2.sqrt, 0.01, depth);
    mix = distance.linexp(0.01, depth, 0.1, 0.8);
    room = distance.linexp(0.01, depth, 0.2, 1);
    in = In.ar(route, 1);
    in = RLPF.ar(
        FreeVerb.ar(in, mix, room, 0.2),
        distance.linlin(0.5, depth, 10000, 1000),
    0.5);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\ms__s__ambisonic8, {
    arg route=20, outbus=0, gate=1, rel=1,
        azimuth=0, elevation=0, elevClip=0.01pi, distance=0, depth=5,
        speakerAzim= #[-0.25pi, -0.5pi, -0.75pi, 1pi, 0.75pi, 0.5pi, 0.25pi, 0],
        speakerElev= #[0, 0, 0, 0, 0, 0, 0, 0],
        speakerDist= #[2, 2, 2, 2, 2, 2, 2, 2], maxDist=2;
    var w, x, y, z, r, s, t, u, v, scaleFlag=1,
        in, signal, out, room, mix;
    distance = distance.linlin(0, 2.sqrt, 0.01, depth);
    mix = distance.linexp(0.01, depth, 0.1, 0.8);
    room = distance.linexp(0.01, depth, 0.2, 1);
    in = In.ar(route, 1);
    in = RLPF.ar(
        FreeVerb.ar(in, mix, room, 0.2),
        distance.linlin(0.5, depth, 10000, 1000),
    0.5);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\ms__s__ambisonic10, {
    arg route=20, outbus=0, gate=1, rel=1,
        azimuth=0, elevation=0, elevClip=0.01pi, distance=0, depth=5,
        speakerAzim= #[-0.15, -0.25pi, -0.5pi, -0.75pi, 1pi, 0.75pi, 0.5pi, 0.25pi, 0.15pi, 0],
        speakerElev= #[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        speakerDist= #[2, 2, 2, 2, 2, 2, 2, 2, 2, 2], maxDist=2;
    var w, x, y, z, r, s, t, u, v, scaleFlag=1,
        in, signal, out, room, mix;
    distance = distance.linlin(0, 2.sqrt, 0.01, depth);
    mix = distance.linexp(0.01, depth, 0.1, 0.8);
    room = distance.linexp(0.01, depth, 0.2, 1);
    in = In.ar(route, 1);
    in = RLPF.ar(
        FreeVerb.ar(in, mix, room, 0.2),
        distance.linlin(0.5, depth, 10000, 1000),
    0.5);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\ms__s__vbap4, {
    arg route=20, outbus=0, gate=1, rel=1,
        azimuth=0.25pi, distance=0.5, elevation=0,
        elevClip=0.1pi, depth=5;
    var speakerAzim=[-45, -140, 140, 45], speakerElev=0, speakerBuff, spread=0;
    var in, amp, signal, out, room, mix;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    distance = distance.linlin(0, 2.sqrt, 0.01, depth);
    mix = distance.linexp(0.01, depth, 0.1, 0.8);
    room = distance.linexp(0.01, depth, 0.2, 1);
    amp = distance.lincurve(0.01, 5, 1, 0.01, 4);
    azimuth = azimuth.linlin(-1pi, 1pi, -180, 180);
    elevation = elevation.linlin(-0.5pi, 0.5pi, -90, 90);
    spread = [100, 0, 4].asSpec.map(distance); // the closer the signal, the more speakers involved (welch-like)
    in = In.ar(route, 1) * amp;
    in = RLPF.ar(
        FreeVerb.ar(in, mix, room, 0.2),
        distance.linlin(0.5, depth, 10000, 1000),
    0.5);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    out = VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\ms__s__vbap2, {
    arg route=20, outbus=0, gate=1, rel=1,
        azimuth=0.25pi, distance=0.5, elevation=0,
        elevClip=0.1pi, depth=5;
    var speakerAzim=[-45, 45], speakerElev=0, speakerBuff, spread=0;
    var in, amp, signal, out, room, mix;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    distance = distance.linlin(0, 2.sqrt, 0.01, depth);
    mix = distance.linexp(0.01, depth, 0.1, 0.8);
    room = distance.linexp(0.01, depth, 0.2, 1);
    amp = distance.lincurve(0.01, 5, 1, 0.01, 4);
    azimuth = azimuth.linlin(-1pi, 1pi, -180, 180);
    elevation = elevation.linlin(-0.5pi, 0.5pi, -90, 90);
    spread = [100, 0, 4].asSpec.map(distance); // the closer the signal, the more speakers involved (welch-like)
    in = In.ar(route, 1) * amp;
    in = RLPF.ar(
        FreeVerb.ar(in, mix, room, 0.2),
        distance.linlin(0.5, depth, 10000, 1000),
    0.5);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    out = VBAP.ar(2, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(outbus, out);
}).send(s);


// RECORDING AND AUDIO
//
SynthDef(\ms__r__rec1, { // mono recording
    arg inbus, bufnum=0, amp=1;
    DiskOut.ar(bufnum, Limiter.ar(amp * InFeedback.ar(inbus, 1), 0.99, 0.01) );
}).send(s);


SynthDef(\ms__r__rec2, { // stereo recording
    arg inbus, bufnum=0, amp=1;
    DiskOut.ar(bufnum, Limiter.ar(amp * InFeedback.ar(inbus, 2), 0.99, 0.01) );
}).send(s);


SynthDef(\ms__r__buffloop, { // continuous recording into buffer
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


SynthDef(\ms__r__authro, { // audio-through
    arg bufnum=0, inbus=0, outbus=0,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
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
    out = signal * EnvGen.kr(Env.adsr(att, 0.1, master, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).send(s);


// MODULATORS
//
SynthDef(\ms__k__sin, {
    arg outbus=0, freq=440, phase=0, mul=1, add=0, mod_mul=0.45, mod_add=0.55, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * SinOsc.kr(LFNoise0.kr(freq, mod_mul, mod_add), LFDClipNoise.kr(freq), mul, add);
    Out.kr(outbus, out);
}).add;

SynthDef(\ms__k__saw, {
    arg outbus=0, freq=440, mul=1, add=0, mod_mul=0.45, mod_add=0.55, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * Saw.kr(LFNoise0.kr(freq, mod_mul, mod_add), mul, add);
    Out.kr(outbus, Saw.kr(freq, mul, add));
}).add;

SynthDef(\ms__k__tri, {
    arg freq=440, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFTri.kr(freq, phase, mul, add);
    Out.kr(outbus, out);
}).add;

// clip noise
SynthDef(\ms__k__clipnoise, {
    arg freq=1, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFDClipNoise.kr(freq, mul, add);
    Out.kr(outbus, out);
}).add;

// step noise
SynthDef(\ms__k__lfnoise0, {
    arg freq=1, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFDNoise0.kr(freq, mul, add);
    Out.kr(outbus, out);
}).add;

SynthDef(\ms__k__lfnoise1, {
    arg freq=1, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFNoise1.kr(freq, mul, add);
    Out.kr(outbus, out );
}).add;

SynthDef(\ms__k__lfnoise2, {
    arg freq=1, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFNoise2.kr(freq).clip2 * mul + add;
    Out.kr(outbus, out );
}).add;

SynthDef(\ms__k__stepnoise, {
    arg freq=1, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * TWChoose.kr(
        Dust.ar(1),
        [LFNoise0.kr(freq, mul, add), LFNoise1.kr(freq, mul, add), LFNoise2.kr(freq).clip2 * mul + add],
        [0.1, 0.4, 0.5]
    );
    Out.kr(outbus, out);
}).add;


// UTILITIES
//
//individual grain (can only be sent to audio in).
SynthDef(\ms__u__grain, {
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
SynthDef(\ms__u__play, {
    arg bufnum=0, busnum=0, amp=1, master=1, att=1, rel=1, gate=1, ca=3, cr= -3,
    pos=0.0, rate=1, dur=0.1;
    var in, out;
    // Synthesis.
    in = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum) * rate, 1, BufFrames.ir(bufnum) * pos, 1);
    // Envelope.
    out = in * EnvGen.kr(Env.adsr(att, 0.1, master, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(busnum, out);
}).send(s);

// Stereo mix-node: LPF input, send summary to outbus
SynthDef(\ms__u__mixNode2, {
    arg inbus=0, outbus=2, gate=1;
    var env, in, out;
    in = Limiter.ar(LPF.ar(InFeedback.ar(inbus, 2), 200) * 0.7);
    env = EnvGen.kr(Env.asr(0.1, 1, 0.5, [3, -3]), gate: gate, doneAction:2);
    out = Mix.ar(in * env);
    Out.ar(outbus, out);
}).send(s);

// Quad mix-node: LPF input, send summary to outbus
SynthDef(\ms__u__mixNode4, {
    arg inbus=0, outbus=4, gate=1;
    var env, in, out;
    in = Limiter.ar(LPF.ar(InFeedback.ar(inbus, 4), 200) * 0.7);
    env = EnvGen.kr(Env.asr(0.1, 1, 0.5, [3, -3]), gate: gate, doneAction:2);
    out = Mix.ar(in * env);
    Out.ar(outbus, out);
}).send(s);

// Hex mix-node: LPF input, send summary to outbus
SynthDef(\ms__u__mixNode6, {
    arg inbus=0, outbus=6, gate=1;
    var env, in, out;
    in = Limiter.ar(LPF.ar(InFeedback.ar(inbus, 6), 200) * 0.7);
    env = EnvGen.kr(Env.asr(0.1, 1, 0.5, [3, -3]), gate: gate, doneAction:2);
    out = Mix.ar(in * env);
    Out.ar(outbus, out);
}).send(s);

// Oct mix-node: LPF input, send summary to outbus
SynthDef(\ms__u__mixNode8, {
    arg inbus=0, outbus=8, gate=1;
    var env, in, out;
    in = Limiter.ar(LPF.ar(InFeedback.ar(inbus, 8), 200) * 0.7);
    env = EnvGen.kr(Env.asr(0.1, 1, 0.5, [3, -3]), gate: gate, doneAction:2);
    out = Mix.ar(in * env);
    Out.ar(outbus, out);
}).send(s);
