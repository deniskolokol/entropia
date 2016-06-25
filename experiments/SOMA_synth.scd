// modular synth project SOMA (from Greek "body")
// S(ynth?), Open, Modular, Analog-ish

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// GENERATORS

//oscilators
SynthDef(\ar_osc_sin, {
    arg freq=440, phase=0, mul=1, add=0, outbus=0;
    Out.ar(outbus, SinOsc.ar(freq, phase, mul, add));
}).add;

SynthDef(\ar_osc_saw, {
    arg freq=440, phase=0, mul=1, add=0, outbus=0;
    Out.ar(outbus, Saw.ar(freq, mul, add));
}).add;

// noise generators
SynthDef(\ar_rnd_white, {
    arg mul=1, add=0, outbus=0;
    Out.ar(outbus, WhiteNoise.ar(mul, add));
}).add;

SynthDef(\ar_rnd_lf, {
    arg freq=500, mul=1, add=0, outbus=0;
    Out.ar(outbus, LFNoise2.ar(freq, mul, add).clip2(-1, 1));
}).add;

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// FILTERS
SynthDef(\flt_lpf, {
    arg freq=500, mul=1, add=0, inbus=1, outbus=0;
    Out.ar(outbus, LPF.ar(In.ar(inbus, 1), freq, mul, add));
}).add;

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// control synths - scales
SynthDef(\kr_stp_scale, {
    arg bufnum=0, key=0, mul=1, add=60, octave=12, detune=0, outbus=8;
    var tone = (
        DegreeToKey.kr(bufnum, key, octave, mul, add)
        + LFNoise1.kr(3, detune)
    ).midicps;
    Out.kr(outbus, tone);
}).add;

// oscilators
SynthDef(\kr_osc_sin, {
    arg freq=440, phase=0, mul=1, add=0, outbus=0;
    Out.kr(outbus, SinOsc.kr(freq, phase, mul, add));
}).add;

SynthDef(\kr_osc_saw, {
    arg freq=440, mul=1, add=0, outbus=0;
    Out.kr(outbus, Saw.kr(freq, mul, add));
}).add;


// ----------------------------------------------------------------------------------------------
// testing

// create new group
g = Group.new;
// add synths to head
a = Synth.head(g, \ar_osc_saw, [\harm, 1, \offset, 60, \mul, 0.2, \outbus, 2]);
w = Synth.head(g, \ar_rnd_white, [\mul, 0.2, \outbus, 2]);
// add processing synth to tail
l = Synth.tail(g, \flt_lpf, [\inbus, 2, \outbus, 4, \freq, 220, \mul, 0.5]);
a.free;
l.free;
w.free;
g.free;

// control bus test (modulation, harmonizer)
// create new group
g = Group.new;
// add kr synth to head
a = Synth.head(g, \kr_osc_sin, [\freq, 1, \mul, 100, \add, 300, \outbus, 8]);
// create a buffer with scale
b = Buffer.loadCollection(s, FloatArray[0, 3, 5, 8, 10]);
// add kr synth harmonizer to head
h = Synth.head(g, \kr_stp_scale, [\bufnum, b.bufnum, \key, 12, \add, 36, \outbus, 9]);
// add ar synth to tail
w = Synth.tail(g, \ar_osc_sin, [\freq, 50, \outbus, 2, \amp, 0.2]);
w.set(\freq, "c8");

(
{20.do { |i|
    var f = i * rrand(100, 1000);
    a.set(\mul, f/2, \add, f);
    ([1/16, 1/4, 1/2] * 2).choose.wait }
}.fork;
)

w.set(\freq, "c9");
{10.do{ |i| h.set(\key, i + 5.rand2); ([1/16, 1/8, 1/4, 1/2] * 2).choose.wait }}.fork;
w.set(\freq, "c");
w.set(\freq, 150);
b.free;
a.free;
h.free;
w.free;
g.free;

(
var group = Dictionary.new;
var presets = Dictionary.new;
var nodeID, groupNodeID, rootNodeID;
var scale;
var bufnum;

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// helper functions

var limInc = { |in=0, lim=inf, step=1|
    // Increments integers with a limit:
    // resets it to 0 every time when inc reaches lim.
    lim = lim + 1;
    ((in + step).clip(0, lim) % (lim))
};

var modThresholds = { |lo=0, hi=1|
    // Universal formula for calculating mod thresholds.
    var mul, add;
    if (hi < lo) {
        [0, 0]
    } {
        mul = (hi - lo) / 2;
        add = hi - mul;
        [mul, add]
    }
};


// preferences
var preferences = (
    maxBufnum: 10,
);

// create root group
rootNodeID = s.nextNodeID;
s.sendMsg("/g_new", rootNodeID);
group[\root] = (nodeID: rootNodeID, name: "Root group");

// create a group for synth
groupNodeID = s.nextNodeID;
s.sendMsg("/g_new", groupNodeID, 0, rootNodeID);
group[\root][\group_1] = (nodeID: groupNodeID, name: "Group 1");

// add .kr synth to head - modulate freq at bus 0
nodeID = m = s.nextNodeID;
s.sendMsg("/s_new", \kr_osc_sin, nodeID, 0, groupNodeID, \freq, 1, \mul, 100, \add, 300, \outbus, 0);
group[\root][\group_1][\synth_1] = (nodeID: nodeID, name: "Synth 1");
// add .kr synth to head - modulate amp at bus 1
nodeID = l = s.nextNodeID;
s.sendMsg("/s_new", \kr_osc_saw, nodeID, 0, groupNodeID, \freq, 2, \mul, 0.3975, \add, 0.4025, \outbus, 1);
group[\root][\group_1][\synth_3] = (nodeID: nodeID, name: "Synth 3");

// scales:
// TO-DO: separate bufnum scope for buffers with files and scale buffers!
// get the current bufnum number (limInc(-1) will return 0).
bufnum = limInc.(bufnum ? -1, preferences.atFail(\maxBufnum, {10}));
// free current buffer before filling it up
s.sendMsg("/b_free", bufnum);
scale = FloatArray[0, 3, 5, 8, 10];
s.sendMsg("/b_alloc", bufnum, scale.size,
    ["/b_set", bufnum] ++ all{:[scale.indexOf(v), v], v <- scale}.flat
);
// add .kr synth to head - scale frequency at bus 9
nodeID = k = s.nextNodeID;
s.listSendMsg(["/s_new", \kr_stp_scale, k, 0, groupNodeID, \bufnum, bufnum, \key, 12, \add, 36, \detune, 0.04, \outbus, 9]);
group[\root][\group_1][\synth_2] = (nodeID: nodeID, name: "Synth 2");

// add .ar synth to tail, map its \freq to control bus 0 and \amp to 1
nodeID = t = s.nextNodeID;
s.sendBundle(0.1,
    ["/s_new", \ar_osc_sin, nodeID, 1, groupNodeID, \freq, 220, \outbus, 0, \amp, 0.1],
    ["/n_map", nodeID, \freq, 0], // freq modulation
    ["/n_map", nodeID, \mul, 1]   // amp modulation
);
group[\root][\group_1][\synth_3] = (nodeID: nodeID, name: "Synth 3");

// automate frequency modulation
{30.do{ |i| f = i * rrand(100, 1000); s.sendBundle(0.01, ["/n_set", m, \mul, f/2], ["/n_set", m, \add, f]); ([1/16, 1/4, 1/2] * 2).choose.wait }}.fork;

// automate scaling
{30.do{ |i| s.sendMsg("/n_set", k, \key, i + 5.rand); ([1/16, 1/8, 1/4, 1/2] * 2).choose.wait }}.fork;

group
)

s.sendMsg("/n_free", 1002)


// TO-DO: how to catch and process server replies? After every message - wait for /done from server before going any further. Check existing quarks for that.
10.do{ |i| s.sendMsg("/b_query", i); }


// GUI
(
w = Window("text-boxes", Rect(200 , 450, 450, 450));
w.view.decorator = FlowLayout(w.view.bounds);

b = EnvelopeView(w, Rect(0, 0, 440, 440))
    .thumbWidth_(60.0)
    .thumbHeight_(15.0)
    .drawLines_(true)
    .drawRects_(true)
    .selectionColor_(Color.red)
    .value_([[0.1, 0.4, 0.5, 0.3], [0.1, 0.2, 0.9, 0.7]]);
4.do({arg i;
    b.setString(i, ["this", "is", "so much", "fun"].at(i));
    b.setFillColor(i,[Color.yellow, Color.white, Color.green].choose);
});
w.front;
)

(
b.connect(3, [2.0,0.0,1.0]); // the text objects can be connected
b.connect(0,[2.0,3.0,1.0]);
)




// for comb reverb use /Applications/SuperCollider/examples/pieces/Little_Man_From_Another_Place.scd

// after completing, try to mimic some of the effects in
// /Applications/SuperCollider/examples/pieces/

// nice start of the song:
// /Applications/SuperCollider/examples/pieces/Termite_College.scd