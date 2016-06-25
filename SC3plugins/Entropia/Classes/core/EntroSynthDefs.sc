EntroSynthDefs {
    classvar s;
    classvar <>params;

	*initClass {
        s = Entropia.srv;

        // params that can be defned in addition to the default ones
        // spatialisers are not included
        params = Dictionary[
            \sr__e__pulse -> [ ],
            \sr__e__plane -> [ ],
            \sr__e__sawy -> [ ],
            \sr__e__dust -> [ ],
            \sr__e__wind -> [ ],
            \sr__i__delay -> [ ],
            \sr__k__sine -> [ ]
        ];

        // ELECTRONIC SYNTHS
        //
        SynthDef(\sr__e__pulse, {
            arg bufnum=0, inbus=30, route=20, trigID=80,
                amp=1, attenuate=0.1, gate=1, att=1, rel=1, ca=3, cr= -3,
                ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
                offset=36, cutoff=0;
            var note, in, out, signal;
            var cutOff, rq, azThresh=0.7;
            // Conversion.
            cutOff = distance.linexp(0.0, 1.0, 200, 10000);
            rq = distance.linlin(0, 2.sqrt, 0.5, 1);
            note = DegreeToKey.kr(bufnum, (az - azThresh).linlin(0, 1 - azThresh, 0, 12), 12, 1, offset).midicps;
            // Synthesis.
            in = Blip.ar(SinOsc.kr(0.5, 0, LFDNoise1.kr(1.5), note), 100, 0.2);
            signal = Mix.ar(in) * amp;
            // Envelope.
            out = signal * EnvGen.kr(
                Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
            SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
            Out.ar(route, out);
        }).send(s);

        SynthDef(\sr__e__plane, {
            arg bufnum=0, inbus=30, route=20, trigID=80, freq=65,
            amp=1, attenuate=0.1, gate=1, att=1, rel=1, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
            offset=36, cutoff=0, rq=0.1;
            var in, out, signal;
            // Synthesis.
            in = LFSaw.ar((1..5) * freq, abs(velocity * 2), velocity)
            + Impulse.ar((0..4) + SinOsc.ar((4..8) * freq).exprange(0.3, 300));
            in = Mix.ar(in) * amp * attenuate;
            signal = RLPF.ar(in,
                freq:LinLin.kr(velocity, 0, 1, 830, 30),
                rq:LFNoise1.kr(velocity.linexp(0, 1, 0.2, 500),
                    velocity.linlin(0, 1, 0.0005, 0.75),
                    velocity.linlin(0, 1, 0.0005, 1.25),
                ),
            );
            // Envelope.
            out = signal * EnvGen.kr(
                Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
            SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
            Out.ar(route, out);
        }).send(s);

        SynthDef(\sr__e__sawy, {
            arg bufnum=0, inbus=30, route=20, trigID=80,
            amp=1, attenuate=0.05, gate=1, att=1, rel=1, ca=3, cr= -3,
            azimuth= -0.5pi, distance=0.5, elevation=0, velocity=0.5,
            offset=36, cutoff= -0.9, rq=0.5, scope=12;
            var note, in, out, signal;
            // Conversion.
            note = DegreeToKey.kr(bufnum, elevation.linlin(-0.5pi, 0.5pi, 0, scope), 12, 1, offset);
            // Clip.
            // cutoff = cutoff.linlin(-1, 1, 10, 20000);
            amp = amp.clip(0, 1);
            note = note.clip(1, 127);
            // Synthesis.
            in = Mix.fill(8, {LFSaw.ar((note + 0.1.rand2).midicps, 0, amp) * attenuate});
            // filter
            signal = RLPF.ar(RLPF.ar(in, cutoff, rq), cutoff, rq);
            // Envelope.
            out = signal * EnvGen.kr(
                Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
            SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
            Out.ar(route, out);
        }).send(s);


        SynthDef(\sr__e__dust, {
            arg bufnum=0, inbus=30, route=20, trigID=80,
            amp=1, attenuate=0.05, gate=1, att=1, rel=1, ca=3, cr= -3,
            azimuth= -0.5pi, distance=0.5, elevation=0, velocity=0.5,
            offset=36, cutoff=1000, rq=0.5, scope=12;
            var note, in, out, signal;

            // XXX - adapt this!
            // var z = Decay.ar(Dust.ar(1.dup, 0.1), 0.3, WhiteNoise.ar);
            // BufCombC.ar(LocalBuf(SampleRate.ir, 2), z, XLine.kr(0.0001, 0.01, 20), 0.2);
            // }.play

            // Conversion.
            note = (
                DegreeToKey.kr(bufnum, elevation.linlin(-0.5pi, 0.5pi, 0, scope), 12, 1, offset)
                + LFNoise1.kr([3, 3], 0.04) // add some low freq stereo detuning
            );
            // Clip.
            cutoff = cutoff.linlin(-1, 1, 10, 20000);
            amp = amp.clip(0, 1);
            note = note.clip(1, 127).midicps;
            // Synthesis.
            in = LFSaw.ar((1..5) * note, abs(velocity * 2), velocity)
            + Impulse.ar((0..4) + SinOsc.ar((4..8) * note).exprange(0.3, 300));
            in = Mix.ar(in) * amp * attenuate;
            // filter
            signal = RLPF.ar(RLPF.ar(in, cutoff, rq), cutoff, rq);
            // Envelope.
            out = signal * EnvGen.kr(
                Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
            SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
            Out.ar(route, out);
        }).send(s);

        SynthDef(\sr__e__wind, {
            arg bufnum=0, inbus=30, route=20, trigID=80,
            amp=1, attenuate=0.05, gate=1, att=1, rel=1, ca=3, cr= -3,
            azimuth= -0.5pi, distance=0.5, elevation=0, velocity=0.5,
            offset=36, cutoff=1000, rq=0.5, scope=12;
            var in, out, signal;
            var fbase, shift;
            // Conversion.
            fbase = offset.linlin(-1, 1, 10, 40);
            shift = ((velocity * 30) ** 3).lag(0.01);
            // Clip.
            cutoff = cutoff.linlin(-1, 1, 10, 20000);
            amp = amp.clip(0, 1);
            // Synthesis.
            in = Formlet.ar(
                WhiteNoise.ar(SinOsc.ar(fbase, shift, 0.5, 1)).min(1),
                // WhiteNoise.ar(SinOsc.ar(fbase, shift, 0.5, 1)).min(1) + SinOsc.ar(fbase, shift),
                LFNoise1.ar(TRand.kr(trig:Delay2.kr(Dust.kr(0.5))), 2450, 2550),
                0.01, 0.1
            ).softclip;
            in = [in, DelayN.ar(in, 0.04, 0.4)];
            in = Mix.fill(4, {AllpassN.ar(in, 0.5, [0.5.rand, 0.5.rand], 4, amp) * attenuate});
            // filter
            signal = RLPF.ar(RLPF.ar(in, cutoff, rq), cutoff, rq);
            // Envelope.
            out = signal * EnvGen.kr(
                Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
            SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
            Out.ar(route, out);
        }).send(s);


        // EFFECTS
        //
        SynthDef(\sr__i__delay, {
            arg bufnum=0, inbus=30, route=20, trigID=80,
            amp=0, attenuate=0.05, gate=1, att=1, rel=1, ca=3, cr= -3,
            azimuth= -0.5pi, distance=0.5, elevation=0, velocity=0.5,
            param1=0, param2=0;
            var in, out, signal;
            // Pass through.
            in = InFeedback.ar(inbus, 1);
            signal = AllpassC.ar(in, param1, param1*1.2, 3, amp);
            // Envelope.
            out = signal * EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
            Out.ar(route, out);
        }).send(s);

        // SPATIALIZERS
        //
        // - spatializer has no attack, but longer \rel to ensure that it will be released after corresponding Gen synth,
        //   since \rel param is sent to both Gen synth and Spatializer.
        //
        SynthDef(\sr__s__ambisonic2, {
            arg route=20, outbus=0, gate=1, rel=1,
            azimuth= -0.5pi, elevation=0, elevClip=0.01pi, distance=0, depth=5,
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

        SynthDef(\sr__s__ambisonic4, {
            arg route=20, outbus=0, gate=1, rel=1,
            azimuth= -0.5pi, elevation=0, elevClip=0.01pi, distance=0, depth=5,
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

        SynthDef(\sr__s__ambisonic6, {
            arg route=20, outbus=0, gate=1, rel=1,
            azimuth= -0.5pi, elevation=0, elevClip=0.01pi, distance=0, depth=5,
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

        SynthDef(\sr__s__ambisonic8, {
            arg route=20, outbus=0, gate=1, rel=1,
            azimuth= -0.5pi, elevation=0, elevClip=0.01pi, distance=0, depth=5,
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

        SynthDef(\sr__s__ambisonic10, {
            arg route=20, outbus=0, gate=1, rel=1,
            azimuth= -0.5pi, elevation=0, elevClip=0.01pi, distance=0, depth=5,
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

        // MODULATORS
        //
        SynthDef(\sr__k__sine, {
            arg outbus=0, lfo=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
            var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
            var out = env * SinOsc.ar(lfo, phase, mul, add);
            SendTrig.kr(Impulse.kr(30), trigID, out);
            Out.kr(outbus, out);
        }).send(s);

        SynthDef(\sr__k__pulse, {
            arg outbus=0, lfo=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
            var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
            var out = env * LFPulse.ar(lfo, phase, mul, add);
            SendTrig.kr(Impulse.kr(30), trigID, out);
            Out.kr(outbus, out);
        }).send(s);

        SynthDef(\sr__k__saw, {
            arg outbus=0, lfo=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
            var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
            var out = env * Saw.kr(lfo, mul, add);
            SendTrig.kr(Impulse.kr(30), trigID, out);
            Out.kr(outbus, out);
        }).send(s);

        SynthDef(\sr__k__tri, {
            arg outbus=0, lfo=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
            var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
            var out = env * LFTri.kr(lfo, phase, mul, add);
            SendTrig.kr(Impulse.kr(30), trigID, out);
            Out.kr(outbus, out);
        }).send(s);

        // clip noise
        SynthDef(\sr__k__clipnoise, {
            arg outbus=0, lfo=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
            var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
            var out = env * LFDClipNoise.kr(lfo, mul, add);
            SendTrig.kr(Impulse.kr(30), trigID, out);
            Out.kr(outbus, out);
        }).send(s);

        // step noise
        SynthDef(\sr__k__lfnoise0, {
            arg outbus=0, lfo=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
            var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
            var out = env * LFDNoise0.kr(lfo, mul, add);
            SendTrig.kr(Impulse.kr(30), trigID, out);
            Out.kr(outbus, out);
        }).send(s);

        SynthDef(\sr__k__lfnoise1, {
            arg outbus=0, lfo=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
            var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
            var out = env * LFNoise1.kr(lfo, mul, add);
            SendTrig.kr(Impulse.kr(30), trigID, out);
            Out.kr(outbus, out );
        }).send(s);

        SynthDef(\sr__k__lfnoise2, {
            arg outbus=0, lfo=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
            var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
            var out = env * LFNoise2.kr(lfo).clip2 * mul + add;
            SendTrig.kr(Impulse.kr(30), trigID, out);
            Out.kr(outbus, out );
        }).send(s);

        SynthDef(\sr__k__stepnoise, {
            arg outbus=0, lfo=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
            var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
            var out = env * TWChoose.kr(
                Dust.ar(1),
                [LFNoise0.kr(lfo, mul, add), LFNoise1.kr(lfo, mul, add), LFNoise2.kr(lfo).clip2 * mul + add],
                [0.2, 0.3, 0.5]
            );
            SendTrig.kr(Impulse.kr(30), trigID, out);
            Out.kr(outbus, out);
        }).send(s);

        SynthDef(\sr__k__sinmod, {
            arg outbus=0, lfo=1, phase=0, mul=1, add=0, mod_mul=0.45, mod_add=0.55, gate=1, att=1, rel=1, trigID=60;
            var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
            var out = env * SinOsc.kr(LFNoise0.kr(lfo, mod_mul, mod_add), LFDClipNoise.kr(lfo), mul, add);
            SendTrig.kr(Impulse.kr(30), trigID, out);
            Out.kr(outbus, out);
        }).send(s);

        SynthDef(\sr__k__sawmod, {
            arg outbus=0, lfo=1, mul=1, add=0, mod_mul=0.45, mod_add=0.55, gate=1, att=1, rel=1, trigID=60;
            var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
            var out = env * Saw.kr(LFNoise0.kr(lfo, mod_mul, mod_add), mul, add);
            SendTrig.kr(Impulse.kr(30), trigID, out);
            Out.kr(outbus, Saw.kr(lfo, mul, add));
        }).send(s);

        SynthDef(\sr__k__keyscale, {
            arg bufnum=0, val=0.5, idx=12, octave=12, detune=3, detuneDepth=0.04,
            outbus=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
            var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
            var note = (
                // `add` here is an offset and must be given in midi!
                DegreeToKey.kr(bufnum, val.linlin(0, 1, 0, idx), octave, mul, add)
                + LFNoise1.kr(detune, detuneDepth) // low freq detuning
            ).midicps;
            var out = env * note;
            SendTrig.kr(Impulse.kr(30), trigID, out);
            Out.kr(outbus, out);
        }).send(s);
    }
}