// ---- SYNTHS ----
SynthDef(\pgl1_lflow, { arg dryBus= 0, wetBus, mod= 0, panidx= 0.8, panshift= 0, amp= 0.1, dry= 0.5, mnote= 0, att= 0.25, rel= 1, crva= 3, crvr= -3, gate= 1, done= 2;
	var env, out, scale = FloatArray[0,2,5,7,10]; // scale
	env= EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: done );
	out= PanX.ar(4,
		LPF.ar(
			LFSaw.ar( mnote + LinLin.kr(mod, -1, 1, 0.01, MouseY.kr(1.5, 0.02, 1))*100 + #[300, 301, 80, 81], 0, 0.8 ).mean,
		2000),
		mod.linlin(-1, 1, -0.1, 1.1),
		amp*mod.linlin(-1, 1, 0.3, 1),
		4
	);
	Out.ar(dryBus, env * out);
	Out.ar(wetBus, env * out * (1 - dry));
}).add;

SynthDef(\pgl1_lfmid, { arg dryBus= 0, wetBus, mod= 0, panidx= 0.8, panshift= 0, amp= 0.1, dry= 0.5, mnote= 0, att= 0.25, rel= 1, crva= 3, crvr= -3, gate= 1, done= 2;
	var env, out;
	env= EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: done );
	out= PanX.ar(4,
		RLPF.ar(
			LFSaw.ar(mnote + LinLin.kr(mod, -1, 1, 0.1, 54) + #[300, 301, 80, 81], 0, 0.8).mean,
			LinLin.kr(mod, -1, 1, 10, 102).midicps, 0.1, 1
		) * 0.5,
		mod.linlin(-1, 1, -0.1, 1.1),
		amp * mod.linlin(-1,1, 0.2, 0.4),
		4
	);
	Out.ar(dryBus, env * out);
	Out.ar(wetBus, env * out * (1 - dry));
}).add;

SynthDef(\pgl1_lfmip, { arg dryBus= 0, wetBus, mod= 0, panidx= 0.8, panshift= 0, amp= 0.1, dry= 0.5, mnote= 0, att= 0.25, rel= 1, crva= 3, crvr= -3, gate= 1, done= 2, freqBase= 85;
	var env, out;
	env= EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: done );
	out= PanX.ar(4,
			RLPF.ar(
				LFSaw.ar(mnote + freqBase + mod.linlin(-1,1, -40, 40)),
				LinLin.kr(mod, -1, 1, 80, 30).midicps, 0.1, 1
			) * 0.5,
		mod.linlin(-1, 1, -0.1, 1.1),
		amp * mod.linlin(-1,1, 0.01, 0.2),
		4
	);
	Out.ar(dryBus, env * out);
	Out.ar(wetBus, env * out * (1 - dry));
}).add;

SynthDef(\pgl1_lfs, { arg dryBus= 0, wetBus, mod= 0, panidx= 0.8, panshift= 0, amp= 0.1, dry= 0.5, freqBase=85, mnote= 0, att= 0.25, rel= 1, crva= 3, crvr= -3, gate= 1, done= 2;
	var env, out;
	env= EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: done );
	out= PanX.ar(4,
		LFSaw.ar(mnote + freqBase + mod.linlin(-1,1, -50, 0)),
		mod.linlin(-1, 1, -0.1, 1.1),
		amp * mod.linlin(-1,1, 0.1, 0.3) * 0.3,
		4
	);
	Out.ar(dryBus, env * out);
	Out.ar(wetBus, env * out * (1 - dry));
}).add;

//sum effect synth
SynthDef(\pgl1_comb, { arg outBus= 30, inBus;
	var input;
	input = In.ar(inBus, 2);
	CombN.ar(input, 0.31, 0.31, 2);
	Out.ar(outBus, input);
}).add;

//control synths - mod
SynthDef(\kr_ml0, { arg outbus= 0, att= 0.1, rel= 1, crva= -3, crvr= 3, gate= 1;
	var env, mod;
	env= EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	mod= env * LorenzL.ar( SinOsc.kr(0.1,20,0.49,0.51), LFNoise0.kr(5, 1, 25), LFNoise0.kr(1, 2, 15), LFNoise0.kr(10, 2, 1) );
	Out.kr(outbus, mod)
}).add;

SynthDef(\kr_mg2, { arg outbus= 0, att= 0.1, rel= 1, crva= -3, crvr= 3, gate= 1;
	var env, mod;
	env= EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	mod= env * Gendy3.kr(2,30,SinOsc.kr(1,0,0.49,0.51),LFNoise0.kr(5, 1, 25), 0.05, SinOsc.kr(0.1,0,0.3,0.1), SinOsc.kr(0.19,0,0.49,0.51),12,10);
	Out.kr(outbus, mod)
}).add;

SynthDef(\kr_mg0, { arg outbus= 0, att= 0.1, rel= 1, crva= -3, crvr= 3, gate= 1;
	var env, mod;
	env= EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	mod= env * Gendy3.kr(6,30,SinOsc.kr(0.1,0,0.49,0.51),SinOsc.kr(0.13,0,0.49,0.51), 0.1, SinOsc.kr(0.27,0,0.49,0.51), SinOsc.kr(0.19,0,0.49,0.51),12,10);
	Out.kr(outbus, mod)
}).add;

SynthDef(\kr_mg1, { arg outbus= 0, freq= 1, att= 0.1, rel= 1, crva= -3, crvr= 3, gate= 1;
	var env, mod;
	env= EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	mod= env * Gendy2.ar(minfreq: freq, maxfreq: freq*5, a:SinOsc.kr(0.4,0,0.05,0.05), c:SinOsc.kr(0.3,0,0.1,0.5), minfreq:0.1);
	Out.kr(outbus, mod)
}).add;

SynthDef(\kr_ml1, { arg outbus= 0, freq=100, att= 0.1, rel= 1, crva= -3, crvr= 3, gate= 1;
	var env, mod;
	env= EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	mod= env * LorenzL.ar( freq, LFNoise0.kr(1, 2, 10), LFNoise0.kr(1, 20, 38), LFNoise0.kr(1, 1.5, 2) );
	Out.kr(outbus, mod)
}).add;

SynthDef(\kr_mh0, { arg outbus= 0, att= 0.1, rel= 1, crva= -3, crvr= 3, gate= 1;
	var env, mod;
	env= EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	mod= env * HenonC.ar( MouseX.kr(1, 200), LFNoise0.kr(1, 0.2, 1.2), LFNoise0.kr(1, 0.15, 0.15) );
	Out.kr(outbus, mod)
}).add;