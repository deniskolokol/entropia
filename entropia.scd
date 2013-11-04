(
// CONSTANTS
// s_ystem, f_ile management, p_arameters, a_udio, o_SC, c_ontrol.
//
var s_INFO = (
    title: "entropia virtual synth",);
var f_SETTINGS_FILENAME = "settings.conf";
var p_FACTORY_SETTINGS = (
    // Audio parameters.
    auxbus:            16, // each synth can be sent to aux output (in addition to outbus) for processing
    output:            0, // main output starts from
    confSurround:      "Ambisonic4",
    depth:             5, // how "far" sound travels beyond the circle of speakers
    master:            1, // master volume
    // System
    synthdefFile:      "entropia_synts.scd",
    tempDir:           "~/tmp/SuperCollider/sounds/");
var a_BUS_POOL = [30, 53]; // lowest and highest-1 number of bus used for synths
var a_SYNTHS = #[\entro__e__lflow, \entro__e__lfmid, \entro__e__lfmip, \entro__e__lfs];
var a_SURROUND_CONFIG = #[\VBAP4, \Ambisonic2, \Ambisonic4, \Ambisonic8];
// Interface descriptor.
// Based on panels, each of which consist of a collection of elements.
// Each element either sets a param or triggers something special,
// in which case a function should be defined.
var p_INTRFACE = [
    (
        title: "Audio settings",
        visible: true,
        params: [
            (param: \confSurround, title: "Surround sound", element: \dropdown, items: a_SURROUND_CONFIG),
            (param: \depth, title: "Aural field depth", spec: ControlSpec(0.5, 10, \lin, 0.5, 4)),
            (param: \auxbus, title: "Aux bus", element: \dropdown, items: (0..29)),
            (param: \output, title: "Main out", element: \dropdown, items: (0..29)),
            (param: \master, title: "Master volume", spec: \amp.asSpec, element: \slider),
        ]
    ),
];


// VARIABLES
//
// Global parameters.
var params, paramsFilename, paramsFile;
var animate=false, count=0;

// System related.
var shutDown;

// Audio routing.
var channels=(0..30);

// Groups and synths.
var groups, kontrols; // main group nodes and .kr nodes container
var groupParams;
var synthCtrlArgs, commonArgs;
var currBusRoute, synthOutbus; // globally changed parameters
var rootNodeID;
var initGroup, releaseGroup, initKr, setParam, broadcastParam, broadcastControl;

// MIDI.
var midiAmp, midiAux, midiNext, midiPrev, midiStream;

// Utils and helper functions.
var clipInc, convertTime;

// Interface.
var win, winRect=Rect(412, 500, 770, 350); //main window
var ctrlTop=20, ctrlHeight=40;
var globalFont1=Font("Helvetica", 9),
    labelFont=Font("Helvetica", 9),
    layoutHFont=Font("Helvetica", 11),
    largeFont=Font("Monaco", 26);
var stStreamReport, btSynthList, msvCtrlSwitch, pmOutBus, knAux, knAmp,
    timeLabel, cvSynths, cvStreams, cvClock;
var btStream= List.new;
var drawPanels;
var layoutHColor=Color.new255(100, 100, 100),
    layoutHFontColor=Color.new255(200, 200, 200),
    panelColor=Color.grey(0.8),
    cvMainColor=Color.grey(0.8),
    btColorOff=Color.new255(250, 250, 250),
    btColorOn=Color.new255(43, 43, 43),
    btColorBG = Color.new255(248, 248, 255),
    stringBackground = Color.grey(alpha:0.1),
    stringColor = layoutHColor,
    menuBackground = Color.white,
    menuStringColor = Color.black,
    listBackground = Color.white,
    listStringColor = Color.black,
    selectedStringColor = nil,
    hiliteColor = nil,
    sliderBackground = Color.grey(alpha:0.5),
    numBackground = Color.white,
    numStringColor = Color.grey(alpha:0.1),
    numNormalColor = Color.black,
    numTypingColor = Color.black,
    knobColor = Color.black,
    background = nil;

// Streams.
var streamList= [nil], fillStream;
var arrBase = #[0, 2, 3, 6], arrDer0 = #[2, 3, 6, 7];


// HELPER FUNCTIONS
//
// Increments integers with a limit: resets to `lo` every time in + step reaches `hi`.
clipInc = { |in=0, step=1, lo=0, hi=inf| ((in + step).clip(lo, hi) % hi).clip(lo, hi)};


// FUNCTIONS
//
// Create new object's group, insert synth and spatializer into it.
initGroup = { |synth, bufnum, output, parm|
    var spatial, groupID, args, l, h;

    #l, h = a_BUS_POOL;
    currBusRoute = clipInc.(currBusRoute ?? l, lo:l, hi:h);
    groupID = s.nextNodeID;
    spatial = "entro__s__" ++ params[\confSurround].toLower; // spatializer's name

    // collect all group args
    args = [\bufnum, bufnum,
        \inbus, params[\inbus], // getting signal from external input
        \outbus, currBusRoute, // feeding into spatilizer
        \input, currBusRoute, // getting signal from synth
        \output, output ? params[\output], // to main output
    ] ++ (parm ? []);

    s.listSendBundle(0.2, [
        ["/error", 1], // turn errors off (locally)
        ["/g_new", groupID, 1, rootNodeID], // add new group to root's tail
        ["/s_new", synth, s.nextNodeID, 0, groupID], // add synth to new group's head
        ["/s_new", spatial, s.nextNodeID, 1, groupID], // add spatializer to new group's tail
        ["/n_set", groupID] ++ args
        ]
    );
    (nodeID: groupID, args: args) // return group dict
};


// Create new object's group, insert synth and spatializer into it.
initKr = { |synth, bufnum, krbus, parm|
    var args, krNodeID = s.nextNodeID;
    args = [\bufnum, bufnum, \krbus, krbus] ++ (parm ? []);

    // add synth to the head of the root group
    s.listSendMsg(["/s_new", synth, krNodeID, 0, rootNodeID] ++ args);

    (nodeID: krNodeID, args: args) // return group dict
};


// Release all synths from group, wait until released, then remove group node from server.
releaseGroup = { |groupID, release=1|
    Routine({
        [
            ["/n_set", groupID, \rel, release, \gate, 0],
            ["/n_free", groupID]
        ].do { |l|
            s.listSendMsg(l);
            release.wait;
        }
    }).play;

    nil // return nil
};


// set param(s) to group or synth
setParam = { |group, parm|
    s.listSendMsg(["/n_set", group[\nodeID]] ++ (parm ?? []))
};


// broadcast params to all groups
broadcastParam = { |parm|
    groups.do { |g| if (g.isNil.not) { setParam.(g, parm) }};
};


// broadcast params to all .kr synths
broadcastControl = { |parm|
    kontrols.do { |k| setParam.(k, parm)};
};


// Convert time to readable format.
convertTime = { |timecode|
    var sec=0, min=0, minstring="00", secstring="00";
    if(timecode >= 60) {
        min = trunc(timecode / 60);
        sec = round(timecode % 60, 0.1);
    } {
        sec = round(timecode,0.1)
    };
    if (min < 10) {minstring = "0"++min.asString} {minstring = min.asString};
    if (sec < 10) {secstring = "0"++sec.asString} {secstring = sec.asString};
    format("%:%", minstring, secstring)
};


// STREAM
//
// fill the stream
fillStream = { arg curr;
	streamList[curr]= Prout({
		loop {
			rrand(2,10).do({
				0.yield;
				arrBase.choose.yield;
				2.yield;
				arrDer0.choose.yield;
			});
			rrand(3,6).do({
				(arrDer0.choose + #[12, 24].choose).yield;
			});
		}
	}).asStream
};


// INITIAL
//
// Useful environment variables.
~currentDir = PathName(thisProcess.nowExecutingPath).pathOnly;

// Global Params.
"\nTrying to open settings file...".postln;
paramsFilename = ~currentDir +/+ f_SETTINGS_FILENAME;
try { // to load from settings file
    params = File(paramsFilename, "r").readAllString.interpret;
    postf("OK\n\n")
} { |err| // unsuccessful
    params = p_FACTORY_SETTINGS; // load factory settings
    format(
        "Failed to open file %!\nUsing factory settings, will be written to the file on exit.\n",
        paramsFilename
    ).warn
};
// complete params: if key not present, fill from factory settings
params = merge(params, p_FACTORY_SETTINGS, { |a, b| a });

// Load synthDefs.
"Loading synth definitions...".postln;
if (PathName(params[\synthdefFile]).pathOnly == "") {
    params[\synthdefFile] = ~currentDir +/+ params[\synthdefFile];
};
if (this.executeFile((params[\synthdefFile])).isNil.not) {
    postf("OK\n\n")
};

// Find or create tmp dir.
~tempDir = params[\tempDir].asAbsolutePath;
if (File.type(~tempDir) != \directory) {File.mkdir(~tempDir)};
if (File.type(~tempDir) == \not_found) { // error!
    format(
        "Failed to find or create temp directory %!\nBuffer recording will not work!",
        ~tempDir
    ).error;
    ~tempDir = nil;
};

// Fill initial values.
rootNodeID = s.nextNodeID; // root group Id for objects' synths
s.sendMsg("/g_new", rootNodeID, 0, 1); // root group at the head of group 1
synthOutbus = 0.dup(4); // [0, 2, 4, 6]; // synth output bus
commonArgs = [\amp, 0.5, \auxbus, params[\auxbus], \aux, 0, \dry, 1];
synthCtrlArgs = [ //[\ctrlSynthName, ctrlBus]
    [\kr_ml0, 0], [\kr_mg2, 1], [\kr_mg0, 2],
    [\kr_ml1, 3], [\kr_mg1, 4], [\kr_mh0, 5]];
groups = Array.fill(a_SYNTHS.size, {nil});
kontrols = Array.fill(synthCtrlArgs.size, {nil});


// INTERFACE
//
win = Window(s_INFO[\title], winRect);
win.view.decorator = FlowLayout(win.view.bounds);
win.layout = GridLayout();

cvSynths = CompositeView().background_(cvMainColor); //synth panel

btSynthList = List.new;
pmOutBus = List.new;
knAux = List.new;
knAmp = List.new;
groups.size.do({ |i| // synth switch on/off
    btSynthList.add( // interface - synth on/off buttons
        Button(cvSynths, Rect(10, i * (ctrlHeight + 3) + ctrlTop, 80, ctrlHeight))
        .states_([
            [a_SYNTHS[i].asString.split($_).last, btColorOn, btColorOff],
            [a_SYNTHS[i].asString.split($_).last, btColorOff, btColorOn]
        ])
        .canFocus_(false)
        .action_({ |bt|
            if (bt.value.booleanValue) { // store group number and params
                groups[i] = initGroup.(a_SYNTHS[i], output: synthOutbus[i],
                    parm: commonArgs ++ [\amp, knAmp[i].value, \master, params[\master]]);
            } {
                groups[i] = releaseGroup.(groups[i][\nodeID]);
            }
        })
    );

	knAmp.add( //synths amp
        Knob(cvSynths, Rect(400, btSynthList[i].bounds.top + 5, 30, 30))
        .value_(commonArgs[commonArgs.indexOf(\amp) + 1])
        .action_({ |kn| setParam.(groups[i], [\amp, kn.value])})
    );

	knAux.add( // aux level (PRE only: isn't affected neither by amp, nor by master)
        Knob(cvSynths,Rect(440, btSynthList[i].bounds.top + 5, 30, 30))
        .value_(commonArgs[commonArgs.indexOf(\aux) + 1])
        .action_({ |kn| setParam.(groups[i], [\aux, kn.value])})
    );

    pmOutBus.add( //dry signal bus
        PopUpMenu(cvSynths, Rect(340, btSynthList[i].bounds.top + 10, 50, 20))
        .background_(btColorBG).font_(layoutHFont).canFocus_(false)
        .items_(channels).value_(synthOutbus[i])
        .action_({ |kn|
            synthOutbus[i] = kn.value;
            setParam.(groups[i], [\output, kn.value])
        })
    );
});


StaticText(cvSynths,Rect(405, 0, 40, 25)).string_("vol").font_(globalFont1);
StaticText(cvSynths,Rect(445, 0, 40, 25)).string_("aux").font_(globalFont1);
StaticText(cvSynths,Rect(110, 0, 30, 25)).string_("---").font_(globalFont1);
synthCtrlArgs.size.do({ |i|
	StaticText(cvSynths,Rect(60+(ctrlHeight * 2) + ((ctrlHeight - 6) * i), 0, ctrlHeight-10, 25)) //ctrl synth labels
		.string_(synthCtrlArgs[i][0].asString.replace("kr_", ""))
		.font_(globalFont1);
});

// Main matrix
msvCtrlSwitch = MultiSliderView(cvSynths, Rect(100, ctrlTop, 235, groups.size * ctrlHeight + 10)) // interface - synth to control buss
.valueThumbSize_(ctrlHeight-10).indexThumbSize_(ctrlHeight).indexIsHorizontal_(false)
.colors_(btColorOff, btColorOn)
.step_(1 / synthCtrlArgs.size)
.value_(Array.fill(groups.size, { 0 })) // size is set automatically when you set the value
.action_({ |msv|
    var bus;
    groups.size.do { |i|
        if(groups[i] != nil) {
            bus = msv.value[i].linlin(0, 1, 0, synthCtrlArgs.size).round;
            s.sendMsg("/n_map", groups[i][\nodeID], \mod, bus-1)
        }
    };
    }
);

// place it
win.layout.addSpanning(VLayout(cvSynths), 1, 1, 2, 2);

//stream controls
cvStreams = CompositeView().background_(cvMainColor);
cvStreams.layout = HLayout();
btStream.add( //task 1 - melody
    Button(cvStreams)
    .states_([["Task 1", btColorOn, btColorOff], ["Task 1", btColorOff, btColorOn]])
    .canFocus_(false)
    .action_({ |bt|
        if (bt.value == 1) {
            btStream.size.do { |j|
                if (btStream[j].value == 1) { // first unpress other buttons
                    if(j != 0, { btStream[j].valueAction_(0) })
                }
            };
            fillStream.value(0); // create the stream
            {
                streamList[0].do { |val|
                    var dur;
                    { stStreamReport.string = val.asString }.defer; // report
                    setParam.(groups[0], [\mnote, (val * 0.75).midicps]);
                    setParam.(groups[1], [\mnote, val.midicps]);
                    setParam.(groups[2], [\mnote, val.midicps]);
                    setParam.(groups[3], [\mnote, (val * 0.2).midicps, \mod, val.linlin(0, 32, 0, -1)]);
                    dur = if (val < 18) {0.25} {2.0.rand};
                    dur.wait;
                }
            }.fork(TempoClock());
        } {
            streamList[0].stop;
            streamList[0]= nil;
        }
    });
);
btStream.add( //task 2 - melody with dynamics
	Button(cvStreams)
    .states_([["Task 2", btColorOn, btColorOff], ["Task 2", btColorOff, btColorOn]])
    .canFocus_(false)
    .action_({ |bt|
        if (bt.value == 1) {
            btStream.size.do({ |j|
                if(btStream[j].value == 1, { // first unpush other buttons
                    if(j != 1, { btStream[j].valueAction_(0) })
                })
            });
            fillStream.value(0); // create the stream
            {
                streamList[0].do{ |val|
                    var dur;
                    { stStreamReport.string = val.asString }.defer; // report
                    setParam.(groups[0], [\mnote, (val*0.75).midicps, \amp, 0.6]);
                    setParam.(groups[1], [\mnote, val.midicps, \mod, 0]);
                    setParam.(groups[2], [\mnote, val.midicps, \mod, 0]);
                    setParam.(groups[3], [\mnote, (val * 0.2).midicps]);
                    setParam.(groups[0], [\gate, 1, \att, 0.05]);
                    setParam.(groups[2], [\gate, 1, \att, 0.5]);
                    setParam.(groups[3], [\gate, 0, \done, 0, \rel, 0.5]);
                    if (val < 18) {
                        setParam.(groups[0], [\gate, 0, \done, 0, \rel, [0.25, 0.5].choose]);
                        setParam.(groups[3], [\gate, 1, \att, 0.5]);
                        2.0.rand.wait;
                        setParam.(groups[0], [\gate, 1, \att, rrand(0.05, 0.75)]);
                        setParam.(groups[3], [\gate, 0, \done, 0, \rel, 0.1]);
                        if (0.3.coin) {
                            setParam.(groups[1], [\mnote, val.midicps-12, \mod, val.linexp(0,18, 0.1, 0.6)]);
                            setParam.(groups[2], [\mnote, val.midicps-12, \mod, val.linexp(0,18, 0.1, 0.6)]);
                            [0.15, 0.5].choose.wait
                        }
                    } {
                        setParam.(groups[0], [\gate, 1, \att, 0.05]);
                        setParam.(groups[3], [\gate, 0, \done, 0, \rel, 0.75]);
                        [0.25, 0.75].choose.wait;
                        setParam.(groups[3], [\gate, 1, \att, 0.5])
                    };
                    dur = if(val < 18) {0.25} {rrand(0.5, 1.5)};
                    dur.wait
                }
            }.fork(TempoClock())
        } {
            streamList[0].stop;
            streamList[0]= nil
        }
    });
);
btStream.add(
    Button(cvStreams, Rect(105, 5, 50, ctrlHeight))
    .states_([["Reset", btColorOn, btColorOff]])
    .canFocus_(false)
    .action_({ |bt|
        {
            groups.size.do { |i|
                if (groups[i] != nil) {
                    setParam.(groups[i], [\mnote, 0])
                }
            }
        }.fork(TempoClock());
    });
);
stStreamReport = StaticText(cvStreams).font_(largeFont);
// place it
win.layout.addSpanning(VLayout(cvStreams), 5, 1, 1, 2);

// Draw panels.
drawPanels = { |win, elements|
    var panel, panelHeight, view, element, label, paramVal, j=1;
    elements.do { |val, i|
        if (val[\visible]) {
            panelHeight = 0;
            panel = VLayout();
            view = CompositeView().background_(panelColor);
            view.decorator = FlowLayout(view.bounds);
            StaticText(view, 230@20)
            .string_(format(" % ", val[\title]))
            .background_(layoutHColor).stringColor_(layoutHFontColor).font_(layoutHFont);
            val[\params].do { |pm|
                paramVal = params[pm[\param]];
                label = pm[\title] ? pm[\param];
                element = pm[\element].switch(
                    \dropdown, {
                        EZPopUpMenu(view, 200@20, label, pm[\items]).font_(layoutHFont)
                        .setColors(stringBackground, stringColor, menuBackground, menuStringColor, background)
                    },
                    \list, {
                        EZListView(view, label:label, items:pm[\items], layout: \vert)
                        .font_(layoutHFont)
                        // Warning! Method setColors of EZListView has bugs!
                        // .setColors(stringBackground, stringColor, listBackground, listStringColor,
                        // selectedStringColor, hiliteColor, background)
                    },
                    \slider, {
                        EZSlider(view, 200@20, label:label, controlSpec:pm[\spec],
                            labelWidth:50, unitWidth:0, numberWidth:30).font_(layoutHFont)
                        .setColors(stringBackground, stringColor, sliderBackground, numBackground,
                            numStringColor, numNormalColor, numTypingColor, knobColor, background)
                    },
                    \boolean, {
                        QCheckBox(view, 200@20).font_(layoutHFont).string_(label);
                    },
                    nil, { // default element is EZNumber
                        EZNumber(view, label:label, controlSpec:pm[\spec], labelWidth:100)
                        .font_(layoutHFont)
                        .setColors(stringBackground, stringColor, numBackground, numStringColor,
                            numNormalColor, numTypingColor, background)
                    }
                );
                panelHeight = panelHeight + element.bounds.height;

                try { // set initial value and define action
                    element.value_(pm[\items].indexOf(paramVal));
                    element.globalAction_({ |e|
                        params[pm[\param]] = pm[\items][e.value];
                        broadcastParam.([pm[\param], e.value]);
                    });
                } { |err|
                    element.value_(paramVal).action_({ |e|
                        params[pm[\param]] = e.value;
                        broadcastParam.([pm[\param], e.value]);
                    });
                };
            };
            panel.add(view);
            win.layout.addSpanning(panel, j, 3, // synth and streams are spanned across 1st 2 columns
                (panelHeight / win.layout.minRowHeight(1)));
            j = j + (panelHeight / win.layout.minRowHeight(1));
        };
    };
};

win.layout.setMinRowHeight(1, 60);
drawPanels.(win, p_INTRFACE);

cvClock = CompositeView().background_(cvMainColor);
timeLabel = StaticText().string_("").font_(largeFont);
cvClock.layout = VLayout(
    [
        HLayout(
            [Button().states_([["Start"], ["Stop"]])
                .action_({ |b| animate = b.value.booleanValue })],
            [Button().states_([["Reset"]])
                .action_({ count = 0; timeLabel.string = convertTime.(count)})],
        )
    ],
    [timeLabel]
);
win.layout.addSpanning(VLayout(cvClock), 5, 3);

// KEYBOARD
//
win.view.keyDownAction = { |view, char, modifiers, unicode, keycode|
    //[char, modifiers, unicode, keycode].postln;
    case
    {keycode == 6} { // Z - info
        if ([0, 256].includes(modifiers)) {
            postf("groups:\n%\n\nkontrols:\n%\n\nglobal params:\n%\n",
                groups, kontrols, params)
        };
    }
};


// MIDI
//
MIDIClient.init;
MIDIIn.connectAll;
midiAmp = [12, 11, 14, 15];
midiAux = [26, 29, 36, 33];
midiNext = [43, 58, 57, 59];
midiPrev = [46, 70, 56, 69];
midiStream = [44, 45];
MIDIFunc.cc({ |val, no| { knAmp[midiAmp.indexOf(no)].valueAction_(\midi.asSpec.unmap(val))}.defer }, midiAmp);
MIDIFunc.cc({ |val, no| { knAux[midiAux.indexOf(no)].valueAction_(\midi.asSpec.unmap(val))}.defer }, midiAux);
//MIDIFunc.cc({ |val, no| broadcastParam.([\master, \midi.asSpec.unmap(val)]) }, 17);
MIDIFunc.cc({ |val, no| broadcastControl.([\freq, val.linlin(0, 127, 1, 200)]) }, 17);
MIDIFunc.noteOff({ |val, no| // next kr
    var index, value;
    {
        value = msvCtrlSwitch.value;
        index = midiNext.indexOf(no);
        value[index] = (msvCtrlSwitch.value[index] + (1 / (kontrols.size + 1))).min(1);
        msvCtrlSwitch.valueAction_(value);
    }.defer;
}, midiNext);
MIDIFunc.noteOff({ |val, no| // prev kr
    var index, value;
    {
        value = msvCtrlSwitch.value;
        index = midiPrev.indexOf(no);
        value[index] = (msvCtrlSwitch.value[index] - (1 / (kontrols.size + 1))).max(0);
        msvCtrlSwitch.valueAction_(value);
    }.defer;
}, midiPrev);
MIDIFunc.noteOff({ |val, no| // streams on / off
    var index;
    {
        index = midiStream.indexOf(no);
        btStream[index].valueAction_(1 - btStream[index].value);
    }.defer;
}, midiStream);


// creare control rate synths at start
synthCtrlArgs.size.do{ |i|
    kontrols[i] = initKr.(synthCtrlArgs[i][0], krbus:synthCtrlArgs[i][1]);
};


{
    while {win.isClosed.not} {
        // blinking "next event" info.
        stStreamReport.visible = (all{: b.value, b <- btStream}.sum > 0);

        // clock
        if (animate) {
            count = count + 1;
            timeLabel.string = convertTime.(count / 10);
        };

        win.refresh;
        0.1.wait;
    }
}.fork(AppClock);

win.front;

// Shutting down.
shutDown = {
    // Free .ar and kr. synths, release root group.
    groups.do({ |g| try { releaseGroup.(g[\nodeID]) }});
    kontrols.do({ |k| try { releaseGroup.(k[\nodeID]) }});
    try { releaseGroup.(rootNodeID) };

    // Close window.
    if (win.isClosed.not) {win.close};

    // MIDI cleanup
    MIDIIn.disconnect;

    // Write params into file.
    "Saving settings!".postln;
    try {
        paramsFile= File.new(paramsFilename, "w");
        paramsFile.write(params.asCompileString);
        paramsFile.close;
    } {
        "WARNING! Cannot write params file!".postln;
    };
    "Good bye...".postln;
};

win.onClose = shutDown;

CmdPeriod.doOnce({shutDown.value()});
\
)