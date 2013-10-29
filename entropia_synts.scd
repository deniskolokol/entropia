// ---- SYNTHS ----
SynthDef(\entro__e__lflow, {
    arg bufnum=0, outbus=20, auxbus=16, aux=0.1, amp=1, master=1, mod=0, mnote=0,
        gate=1, att=0.2, rel=1, ca=3, cr= -3, done=2;
	var in, out, env;
    env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: done);
    // bookmark - to-do: get rid of MouseY, re-allocate it to args!
	in = LPF.ar(
        LFSaw.ar(mnote
            + LinLin.kr(mod, -1, 1, 0.01, MouseY.kr(1.5, 0.02, 1)) * 100 + #[300, 301, 80, 81], 0, 0.8
        ).mean, 2000);
    out = Mix.ar(in) * env;
	Out.ar(auxbus, out * aux);
	Out.ar(outbus, out * amp * master);
}).add;

SynthDef(\entro__e__lfmid, {
    arg bufnum=0, outbus=20, auxbus=16, aux=0.1, amp=1, master=1, mod=0, mnote=0,
        gate=1, att=0.2, rel=1, ca=3, cr= -3, done=2;
	var in, out, env;
    env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: done);
	in = RLPF.ar(
			LFSaw.ar(mnote + LinLin.kr(mod, -1, 1, 0.1, 54) + #[300, 301, 80, 81], 0, 0.8).mean,
			LinLin.kr(mod, -1, 1, 10, 102).midicps, 0.1, 1
		);
    out = Mix.ar(in) * env;
	Out.ar(auxbus, out * aux);
	Out.ar(outbus, out * amp * master);
}).add;

SynthDef(\entro__e__lfmip, {
    arg bufnum=0, outbus=20, auxbus=16, aux=0.1, amp=1, master=1, mod=0, mnote=0,
        gate=1, att=0.2, rel=1, ca=3, cr= -3, done=2;
	var in, out, env;
    var freqBase = 85;
    env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: done);
	in = RLPF.ar(
        LFSaw.ar(mnote + freqBase + mod.linlin(-1,1, -40, 40)),
        LinLin.kr(mod, -1, 1, 80, 30).midicps, 0.1, 1
    );
    out = Mix.ar(in) * env;
	Out.ar(auxbus, out * aux);
	Out.ar(outbus, out * amp * master);
}).add;

SynthDef(\entro__e__lfs, {
    arg bufnum=0, outbus=20, auxbus=16, aux=0.1, amp=1, master=1, mod=0, mnote=0,
        gate=1, att=0.2, rel=1, ca=3, cr= -3, done=2;
	var in, out, env;
    var freqBase = 85;
    env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: done);
	in = LFSaw.ar(mnote + freqBase + mod.linlin(-1,1, -50, 0));
    out = Mix.ar(in) * env;
	Out.ar(auxbus, out * aux);
	Out.ar(outbus, out * amp * master);
}).add;

//control synths - mod
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
    arg krbus=0, att=0.1, rel=1, ca=3, cr= -3, gate=1, freq=1;
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
        azimuth=0, elevation=0, elevClip=0.1pi, distance=0.2, depth=5;
    var w, x, y, z, r, s, t, u, v,
        speakerAzim = [-0.16pi, 0.16pi], speakerElev = 0, speakerDist = [0.35, 0.35],
        maxDist=3, scaleFlag=1,
        in, signal, env, out;
    distance = distance.linlin(0, 2.sqrt, 0.5, depth);
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
        azimuth=0, elevation=0, elevClip=0.1pi, distance=0, depth=5;
    var w, x, y, z, r, s, t, u, v,
        speakerAzim= [-0.25pi, -0.6pi, 0.6pi, 0.25pi], speakerElev= 0, speakerDist= [2, 2, 2, 2],
        maxDist=3, scaleFlag=1,
        in, signal, env, out;
    distance = distance.linlin(0, 2.sqrt, 0.5, depth);
    azimuth = mod * 1pi;
    in = In.ar(input, 1);
    env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: done);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: done);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(output, out);
}).send(s);


SynthDef(\entro__s__ambisonic8, {
    arg input=20, output=0, mod=1,
        gate=1, att=0.2, rel=1, ca=3, cr= -3, done=2,
        azimuth=0, elevation=0, elevClip=0.1pi, distance=0, depth=5;
    var w, x, y, z, r, s, t, u, v,
        speakerAzim=[-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev=0,
        speakerDist=[6.3, 4.7, 6, 6, 6, 4.7, 6.3, 6.3], maxDist=6.3, scaleFlag=1,
        in, signal, env, out;
    distance = distance.linlin(0, 2.sqrt, 0.5, depth);
    azimuth = mod * 1pi;
    in = In.ar(input, 1);
    env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: done);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: done);
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
