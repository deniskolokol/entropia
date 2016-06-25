// SYNTHS
//
SynthDef(\entro__e__lflow, {
    arg bufnum=0, outbus=20, auxbus=16, aux=0.1, amp=1, master=1, mod=0, mnote=0, delay=0, reverb=0,
        gate=1, att=0.2, rel=1, ca=3, cr= -3, done=2;
	var in, out, env;
    env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: done);
    // bookmark - to-do: get rid of MouseY, re-allocate it to args!
    in = MidEQ.ar(
        RLPF.ar(
            LFSaw.ar(mnote + LinLin.kr(mod, -1, 1, 0.01, MouseY.kr(1.5, 0.02, 1)) * 100 + #[300, 301, 80, 81]).mean,
            LinLin.kr(mod, -1, 1, 200, 5000), 0.8
        ),
        // MidEQ is following the resonant low pass
        LinLin.kr(mod, -1, 1, 210, 4980), LinLin.kr(mod, -1, 1, 0.4, 0.8), 6
    );
    in = CombC.ar(in, 0.4, delay.linexp(0.001, 1, 0.001, 0.4), delay * 5);
    in = FreeVerb.ar(in, reverb, reverb.linexp(0.001, 1, 0.5, 0.9), 0.3);
    out = Normalizer.ar(in) * env;
	Out.ar(auxbus, out * aux);
	Out.ar(outbus, out * amp * master);
}).add;

SynthDef(\entro__e__lfmid, {
    arg bufnum=0, outbus=20, auxbus=16, aux=0.1, amp=1, master=1, mod=0, mnote=0, delay=0, reverb=0,
        gate=1, att=0.2, rel=1, ca=3, cr= -3, done=2;
	var in, out, env;
    env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: done);
	in = MidEQ.ar(
        RLPF.ar(
            LFSaw.ar(mnote + LinLin.kr(mod, -1, 1, 0.1, 54) + #[300, 301, 80, 81], 0, 0.8).mean,
            LinLin.kr(mod, -1, 1, 70, 112).midicps, 0.3, 1
        ),
        LinLin.kr(mod, -1, 1, 70, 95).midicps, 0.2, 8
    );
    in = CombC.ar(in, 0.4, delay.linexp(0.001, 1, 0.001, 0.4), delay * 5);
    in = FreeVerb.ar(in, reverb, reverb.linexp(0.001, 1, 0.5, 0.9), 0.3);
    out = Normalizer.ar(in) * env;
	Out.ar(auxbus, out * aux);
	Out.ar(outbus, out * amp * master);
}).add;

SynthDef(\entro__e__lfmip, {
    arg bufnum=0, outbus=20, auxbus=16, aux=0.1, amp=1, master=1, mod=0, mnote=0, delay=0, reverb=0,
        gate=1, att=0.2, rel=1, ca=3, cr= -3, done=2;
	var in, out, env;
    var freqBase = 85;
    env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: done);
	in = RLPF.ar(
        LFSaw.ar(mnote + freqBase + mod.linlin(-1,1, -40, 40)),
        LinLin.kr(mod, -1, 1, 80, 30).midicps, 0.1, 1
    );
    in = CombC.ar(in, 0.2, 0.2, delay * 3);
    in = FreeVerb.ar(in, reverb, reverb.linexp(0.001, 1, 0.5, 0.9), 0.3);
    out = Mix.ar(in) * env;
	Out.ar(auxbus, out * aux);
	Out.ar(outbus, out * amp * master);
}).add;

SynthDef(\entro__e__lfs, {
    arg bufnum=0, outbus=20, auxbus=16, aux=0.1, amp=1, master=1, mod=0, mnote=0, delay=0, reverb=0,
        gate=1, att=0.2, rel=1, ca=3, cr= -3, done=2;
	var in, out, env;
    var freqBase = 85;
    env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: done);
	in = LFSaw.ar(mnote + freqBase + mod.linlin(-1, 1, -50, 0));
    4.do(
        {in = AllpassN.ar(in, 0.1,
            [
                TRand.kr(0.01.rand, 0.1.rand, Dust.kr(0.1)),
                TRand.kr(0.01.rand, 0.05.rand, Dust.kr(0.5))
            ], 4)
        });
    in = CombC.ar(in, 0.4, delay.linexp(0.001, 1, 0.001, 0.4), delay * 5);
    in = FreeVerb.ar(in, reverb, reverb.linexp(0.001, 1, 0.5, 0.9), 0.3);
    in = Mix.ar(in);
    out = in * env;
	Out.ar(auxbus, out * aux);
	Out.ar(outbus, out * amp * master);
}).add;


// CONTROL SYNTHS (\mod)
//
SynthDef(\kr_ml0, {
    arg krbus=0, att=0.1, rel=1, ca=3, cr= -3, gate=1, freq=1;
	var env, mod;
	env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    mod = LorenzL.ar(SinOsc.kr(freq, 0, 0.49, 0.51), LFNoise0.kr(5, 1, 25), LFNoise0.kr(1, 2, 15), LFNoise0.kr(10, 2, 1));
	Out.kr(krbus, mod * env)
}).add;

SynthDef(\kr_mg2, {
    arg krbus=0, att=0.1, rel=1, ca=3, cr= -3, gate=1, freq=1;
	var env, mod;
	env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
	mod = Gendy3.kr(2, 30, SinOsc.kr(1, 0, 0.49, 0.51),
        LFNoise0.kr(5, 1, 25), freq / 20,
        SinOsc.kr(0.1, 0, 0.3, 0.1), SinOsc.kr(0.19, 0, 0.49, 0.51), 12, 10);
	Out.kr(krbus, mod * env)
}).add;

SynthDef(\kr_mg0, {
    arg krbus=0, att=0.1, rel=1, ca=3, cr= -3, gate=1, freq=1;
	var env, mod;
	env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
	mod = Gendy3.kr(6, 30, SinOsc.kr(0.1, 0, 0.49, 0.51),
        SinOsc.kr(0.13, 0, 0.49, 0.51), 0.1, SinOsc.kr(0.27, 0, 0.49, 0.51),  SinOsc.kr(0.19, 0, 0.49, 0.51), 12, 10);
	Out.kr(krbus, mod * env)
}).add;

SynthDef(\kr_ml1, {
    arg krbus=0, att=0.1, rel=1, ca=3, cr= -3, gate=1, freq=100;
	var env, mod;
	env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
	mod = LorenzL.ar(freq, LFNoise0.kr(1, 2, 10), LFNoise0.kr(1, 20, 38), LFNoise0.kr(1, 1.5, 2));
	Out.kr(krbus, mod * env)
}).add;

SynthDef(\kr_mg1, {
    arg krbus=0, att=0.1, rel=1, ca=3, cr= -3, gate=1, freq=1;
	var env, mod;
	env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
	mod = Gendy2.ar(minfreq: freq, maxfreq: freq * 5, a:SinOsc.kr(0.4, 0, 0.05, 0.05), c:SinOsc.kr(0.3, 0, 0.1, 0.5), minfreq:0.1);
	Out.kr(krbus, mod * env)
}).add;

SynthDef(\kr_mh0, {
    arg krbus=0, att=0.1, rel=1, ca=3, cr= -3, gate=1, freq=1000;
	var env, mod;
	env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    mod = HenonC.ar(freq, LFNoise0.kr(1, 0.2, 1.2), LFNoise0.kr(1, 0.15, 0.15));
	Out.kr(krbus, mod * env)
}).add;

SynthDef(\kr_mn0, {
    arg krbus=0, att=0.1, rel=1, ca=3, cr= -3, gate=1, freq=1;
	var env, mod;
	env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    mod = LFNoise1.kr(LFNoise0.kr(1, 0.2, 1.2), LFNoise2.kr(1, 0.4, 0.6), LFNoise0.kr(1, 0.15, 0.15));
	Out.kr(krbus, mod * env)
}).add;

// GRANULAR SYNTHS
//
// bookmark
// finish it!

// SPATIALIZERS
//
// Warning!
// For this particular piece spatializers have to have the same kind of Env
// and its parameters (gate, att, rel, ca, cr, done) as well as `mod`parameter,
// since messages sent to group should affect both generator and spatializer
// in the same way!
//
// Ambisonic notes:
// - distance of the object from the center should always be corrected with respect to field depth.
// - distance artificially moved to 0.5 from the center to eliminate feedback.
//
SynthDef(\entro__s__ambisonic2, {
    arg input=20, output=0, mod=1,
        gate=1, att=0.2, rel=1, ca=3, cr= -3, done=2,
        azimuth=0, elevation=0, elevClip=0.1pi, distance=0.1, depth=2;
    var w, x, y, z, r, s, t, u, v,
        speakerAzim = [-0.16pi, 0.16pi], speakerElev = 0, speakerDist = [2, 2],
        maxDist=3, scaleFlag=1,
        in, signal, env, out;
    distance = distance.linlin(0, 2.sqrt, 0.01, depth);
    azimuth = mod * 1pi;
    in = In.ar(input, 1);
    env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: done);
    signal = in * env; // EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: done);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(output, out);
}).send(s);


SynthDef(\entro__s__ambisonic4, {
    arg input=20, output=0, mod=1,
        gate=1, att=0.2, rel=1, ca=3, cr= -3, done=2,
        azimuth=0, elevation=0, elevClip=0.1pi, distance=0.2, depth=5;
    var w, x, y, z, r, s, t, u, v,
        speakerAzim= [-0.25pi, -0.6pi, 0.6pi, 0.25pi], speakerElev= 0, speakerDist= [2, 2, 2, 2],
        maxDist=2, scaleFlag=1,
        in, signal, env, out;
    distance = distance.linlin(0, 2.sqrt, 0.5, depth);
    azimuth = mod * 1pi;
    in = In.ar(input, 1);
    env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: done);
    signal = in * env;
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(output, out);
}).send(s);


SynthDef(\entro__s__ambisonic6, {
    arg input=20, output=0, mod=1,
        gate=1, att=0.2, rel=1, ca=3, cr= -3, done=2,
        azimuth=0, elevation=0, elevClip=0.1pi, distance=0.2, depth=5;
    var w, x, y, z, r, s, t, u, v,
        speakerAzim= [-0.17pi, -0.2pi, -0.64pi, 0.65pi, 0.28pi, 0.1pi], speakerElev= [0, 0, 0, 0, 0, 0],
        speakerDist= [13.7, 7.7, 5.6, 4.9, 7.5, 12.7],
        maxDist=13.7, scaleFlag=1,
        in, signal, env, out;
    distance = distance.linlin(0, 2.sqrt, 0.5, depth);
    azimuth = mod * 1pi;
    in = In.ar(input, 1);
    env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: done);
    signal = in * env;
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(output, out);
}).send(s);


SynthDef(\entro__s__ambisonic8, {
    arg input=20, output=0, mod=1,
        gate=1, att=0.2, rel=1, ca=3, cr= -3, done=2,
        azimuth=0, elevation=0, elevClip=0.1pi, distance=0.2, depth=5;
    var w, x, y, z, r, s, t, u, v,
        speakerAzim=[-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev=0,
        speakerDist=[2, 2, 2, 2, 2, 2, 2, 2], maxDist=2, scaleFlag=1,
        in, signal, env, out;
    distance = distance.linlin(0, 2.sqrt, 0.5, depth);
    azimuth = mod * 1pi;
    in = In.ar(input, 1);
    env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: done);
    signal = in * env;
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(output, out);
}).send(s);


SynthDef(\entro__s__vbap4, {
    arg input=20, output=0, mod=1,
        gate=1, att=0.2, rel=1, ca=3, cr= -3, done=2,
        azimuth=0, elevation=0, elevClip=0.1pi, distance=0, depth=5;
    var speakerAzim = #[-45, -140, 140, 45], speakerElev=0, speakerBuff, spread=0,
        in, signal, env, out;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    azimuth = mod.linlin(-1, 1, -180, 180);
    elevation = elevation.linlin(-0.5pi, 0.5pi, -90, 90);
    spread = [50, 0, 4].asSpec.map(distance); // the closer the signal, the more speakers involved (welch-like)
    in = In.ar(input, 1);
    env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: done);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: done);
    out = VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(output, out);
}).send(s);
