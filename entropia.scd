(
// CONSTANTS
// f_ile management, p_arameters, a_udio, o_SC, c_ontrol.
//
var f_SETTINGS_FILENAME = "settings.conf";
var p_FACTORY_SETTINGS = (
    // Audio parameters.
    wetBus:            16,
    effBus:            30,
    outbus:            0, // main output starts from
    confSurround:      "Ambisonic4",
    fieldDepth:        5, // how "far" sound travels beyond the circle of speakers
    master:            1, // master volume
    // System
    synthdefFile:      "entropia_synts.scd",
    tempDir:           "~/tmp/SuperCollider/sounds/");
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
            (param: \fieldDepth, title: "Aural field depth", spec: ControlSpec(0.5, 10, \lin, 0.5, 4)),
            (param: \wetBus, title: "Wet bus", element: \dropdown, items: (0..29)),
            (param: \effBus, title: "Effect bus", element: \dropdown, items: (0..29)),
            (param: \outbus, title: "Main out", element: \dropdown, items: (0..29)),
            (param: \master, title: "Master volume", spec: \amp.asSpec, element: \slider),
        ]
    ),
];


// VARIABLES
//
// Global parameters.
var params, paramsFilename, paramsFile;

// System related.
var shutDown;

// Audio.
var effSynthName = \pgl1_comb;
var synthNames = List[\pgl1_lflow, \pgl1_lfmid, \pgl1_lfmip, \pgl1_lfs];
var synthArgs, synthCtrlArgs;
var effSynth;
var synthList= [nil, nil, nil, nil];
var synthCtrl= List.new;
var channels= 52, chlistMono= Array.fill(channels, nil);

// MIDI.
var ccResp, nOnResp, midiSrc= 1219363690; // X-Session Pro

// Functions.
var startStopSynth, setParam;

// Interface.
var win, winRect=Rect(412, 500, 770, 350); //main window
var ctrlTop=20, ctrlHeight=40;
var globalFont1=Font("Helvetica", 9),
    labelFont=Font("Helvetica", 9),
    layoutHFont=Font("Helvetica", 11);
var cvSynths, cvStreams, btSynthList= List.new, msvCtrlSwitch, pmDryBus= List.new, knWetLevel= List.new, knAmp= List.new;
var btTask= List.new;
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
var arrBase= #[0, 2, 3, 6], arrDer0= #[2, 3, 6, 7];


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

//fill channels list
channels.do({ |i| chlistMono.put(i, i.asSymbol) });

// synth args
synthArgs = [
    [\dryBus, 0, \wetBus, params[\wetBus], \amp, 0.5, \dry, 1],
    [\dryBus, 2, \wetBus, params[\wetBus], \amp, 0.5, \dry, 1],
    [\dryBus, 4, \wetBus, params[\wetBus], \amp, 0.5, \dry, 1],
    [\dryBus, 6, \wetBus, params[\wetBus], \amp, 0.5, \dry, 1]];
synthCtrlArgs = [ //[\synthName, ctrl bus]
    [\kr_ml0, 0], [\kr_mg2, 1], [\kr_mg0, 2],
    [\kr_ml1, 3], [\kr_mg1, 4], [\kr_mh0, 5] ];


// INTERFACE
//
win = Window("PG_L1 ctrl", winRect);
win.view.decorator = FlowLayout(win.view.bounds);
win.layout = GridLayout();

cvSynths = CompositeView().background_(cvMainColor); //synth panel

StaticText(cvSynths,Rect(ctrlHeight+65, 0, 40, 25)) //synths volume
	.string_("vol")
	.font_(globalFont1);
StaticText(cvSynths,Rect(ctrlHeight+105, 0, 40, 25)) //"send" label
	.string_("send")
	.font_(globalFont1);

synthList.size.do({ |i| // synth switch on/off
    btSynthList.add( // interface - synth on/off buttons
        Button(cvSynths, Rect(10, i*ctrlHeight+ctrlTop, 80, ctrlHeight))
        .states_([
            [synthNames[i].asString, btColorOn, btColorOff],
            [synthNames[i].asString, btColorOff, btColorOn]
        ])
        .canFocus_(false)
        .action_({ |bt| startStopSynth.value(i, synthArgs[i], knAmp[i].value)})
    );
	knAmp.add( //synths amp
        Knob(cvSynths,Rect(100, btSynthList[i].bounds.top+5, 30, 19))
        .value_(synthArgs[i][5])
        .action_({ |kn|
            synthArgs[i][5]= kn.value;
            setParam.value(i, synthArgs[i][4], synthArgs[i][5])
        });
    );
	knWetLevel.add( //dry/wet level
        Knob(cvSynths,Rect(140, btSynthList[i].bounds.top+5, 30, 19))
        .action_({ |kn|
            synthArgs[i][7]= 1-kn.value;
            setParam.value(i, synthArgs[i][6], synthArgs[i][7])
        });
    );
    pmDryBus.add( //dry signal busses
        PopUpMenu(cvSynths,Rect(440, btSynthList[i].bounds.top, 40, 19))
        .background_(btColorBG)
        .canFocus_(false)
        .font_(globalFont1)
        .items_(chlistMono)
        .value_(synthArgs[i][1])
        .action_({ |pm|
            synthArgs[i][1]= pm.value;
            if(synthList[i] != nil, {synthList[i].set(\dryBus, pm.value)});
        });
    );
});

StaticText(cvSynths,Rect(ctrlHeight+153, 0, 30, 25)) //ctrl synth labels
	.string_("---")
	.font_(globalFont1);

synthCtrlArgs.size.do({ |i|
	StaticText(cvSynths,Rect(135+(ctrlHeight*2)+((ctrlHeight-5)*i), 0, ctrlHeight-10, 25)) //ctrl synth labels
		.string_(synthCtrlArgs[i][0].asString.replace("kr_", ""))
		.font_(globalFont1);
});
// WARNING! elaborate the same interface with Grid (see help)
msvCtrlSwitch = MultiSliderView(cvSynths, Rect(180, ctrlTop, 235, synthList.size * ctrlHeight + 10)) // interface - synth to control buss
	.step_(1/synthCtrlArgs.size)
	.valueThumbSize_(ctrlHeight-10)
	.indexThumbSize_(ctrlHeight)
	.indexIsHorizontal_(false)
	.colors_(btColorOff, btColorOn)
	.value_(Array.fill(synthList.size, { 0 })) // size is set automatically when you set the value
	.action_({ |msv|
		var tmpVar;
		synthList.size.do({ |i|
			if(synthList[i] != nil, {
				tmpVar= round(msv.value[i].linlin(0,1, 0,synthCtrlArgs.size), 1);
				if(tmpVar == 0, {
					synthList[i].set(\mod, "c")
				}, {
					synthList[i].set(\mod, "c"++(tmpVar-1).asString)
				})
			})
		});
	});
// place it
win.layout.addSpanning(VLayout(cvSynths), 1, 1, 2, 2);

//stream controls
cvStreams = CompositeView().background_(cvMainColor);
btTask.add( //task 1 - melody
	Button(cvStreams, Rect(5, 5, 45, ctrlHeight))
		.states_([
			["Task 1", btColorOn, btColorOff],
			["Task 1", btColorOff, btColorOn]
		])
		.canFocus_(false)
		.action_({ |bt|
			if(bt.value == 1, {
				btTask.size.do({ |j|
					if(btTask[j].value == 1, { // first unpush other buttons
						if(j != 0, { btTask[j].valueAction_(0) })
					})
				});
				fillStream.value(0); // create the stream
				{
					streamList[0].do{ |val|
						var dur;
						val.postln;
						synthList[0].set(\mnote, (val*0.75).midicps);
						synthList[1].set(\mnote, val.midicps);
						synthList[2].set(\mnote, val.midicps);
						synthList[3].set(\mnote, (val * 0.2).midicps, \mod, val.linlin(0,32, 0, -1));
						dur= if(val < 18, {0.25}, {2.0.rand});
						dur.wait;
					}
				}.fork(TempoClock());
			}, {
				streamList[0].stop; streamList[0]= nil
			});
		});
);
btTask.add( //task 2 - melody with dynamics
	Button(cvStreams, Rect(55, 5, 45, ctrlHeight))
		.states_([
			["Task 2", btColorOn, btColorOff],
			["Task 2", btColorOff, btColorOn]
		])
		.canFocus_(false)
		.action_({ |bt|
			if(bt.value == 1, {
				btTask.size.do({ |j|
					if(btTask[j].value == 1, { // first unpush other buttons
						if(j != 1, { btTask[j].valueAction_(0) })
					})
				});
				fillStream.value(0); // create the stream
				{
					streamList[0].do{ |val|
						var dur;
						val.postln;
						synthList[0].set(\mnote, (val*0.75).midicps, \amp, 0.6);
						synthList[1].set(\mnote, val.midicps, \mod, 0);
						synthList[2].set(\mnote, val.midicps, \mod, 0);
						synthList[3].set(\mnote, (val * 0.2).midicps);
						dur= if(val < 18, {0.25}, {rrand(0.5, 1.5)});

						synthList[0].set(\gate, 1, \att, 0.05);
						synthList[2].set(\gate, 1, \att, 0.5);
						synthList[3].set(\gate, 0, \done, 0, \rel, 0.5);
						if(val < 18, {
							synthList[0].set(\gate, 0, \done, 0, \rel, [0.25, 0.5].choose);
							synthList[3].set(\gate, 1, \att, 0.5);
							2.0.rand.wait;
							synthList[0].set(\gate, 1, \att, rrand(0.05, 0.75));
							synthList[3].set(\gate, 0, \done, 0, \rel, 0.1);
							if(0.3.coin, {
								synthList[1].set(\mnote, val.midicps-12, \mod, val.linexp(0,18, 0.1, 0.6));
								synthList[2].set(\mnote, val.midicps-12, \mod, val.linexp(0,18, 0.1, 0.6));
								[0.15, 0.5].choose.wait;
							});
						}, {
							synthList[0].set(\gate, 1, \att, 0.05);
							synthList[3].set(\gate, 0, \done, 0, \rel, 0.75);
							[0.25, 0.75].choose.wait;
							synthList[3].set(\gate, 1, \att, 0.5);
						});
						dur.wait;
					}
				}.fork(TempoClock());
			}, {
				streamList[0].stop; streamList[0]= nil
			});
		});
);
btTask.add(
	Button(cvStreams, Rect(105, 5, 45, ctrlHeight))
		.states_([
			["Reset", btColorOn, btColorOff]
		])
		.canFocus_(false)
		.action_({ |bt|
			{
				synthList.size.do{ |i|
					if(synthList[i] != nil, {
						synthList[i].set(\mnote, 0)
					})
				}
			}.fork(TempoClock());
		});
);
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
                    element.globalAction_({ |e| params[pm[\param]] = pm[\items][e.value]});
                } { |err|
                    element.value_(paramVal).action_({ |e| params[pm[\param]] = e.value});
                };
            };
            panel.add(view);
            [panelHeight, win.layout.minRowHeight(1)].postln;
            win.layout.addSpanning(panel, j, 3, // synth and streams are spanned across 1st 2 columns
                (panelHeight / win.layout.minRowHeight(1)));
            j = j + (panelHeight / win.layout.minRowHeight(1));
        };
    };
};

// Draw first column
win.layout.setMinRowHeight(1, 60);
drawPanels.(win, p_INTRFACE);


// PROCEDURES
//
// Start/stop current synth
startStopSynth = { arg curr, args;
	if(synthList[curr] == nil, {
		synthList[curr]= Synth.before(effSynth, synthNames[curr], args);
	}, {
		synthList[curr].set(\gate, 0, \done, 2);
		synthList[curr]= nil;
	})
};

// start/stop current synth
setParam = { arg curr, parm, val;
	if(synthList[curr] != nil, { synthList[curr].set(parm, val) })
};

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

// control
MIDIClient.init; // intialize the client
13.do({ arg i; MIDIIn.connect(i, MIDIClient.sources.at(i)); });
ccResp = CCResponder({|src, chan, num, val|
	[src,chan,num,val].postln;
    case
    {num == 86} {{btSynthList[0].valueAction_(1-btSynthList[0].value)}.defer}
    {num == 89} {{btSynthList[1].valueAction_(1-btSynthList[1].value)}.defer}
    {num == 119} {{btSynthList[2].valueAction_(1-btSynthList[2].value)}.defer}
    {num == 10} {synthCtrlArgs.size.do({|j| synthCtrl[j].set(\freq, val.linlin(0,127, 1,200))})}
    // Wet ctrl
    {num == 12} {{knWetLevel[0].valueAction_(val.linlin(0,127, 0,1))}.defer}
    {num == 11} {{knWetLevel[1].valueAction_(val.linlin(0,127, 0,1))}.defer}
    {num == 14} {{knWetLevel[2].valueAction_(val.linlin(0,127, 0,1))}.defer}
    {num == 15} {{knWetLevel[3].valueAction_(val.linlin(0,127, 0,1))}.defer}
    {(num >= 52) && (num < 56)} {{knAmp[num-52].valueAction_(val.linlin(0,127, 0,1))}.defer}
   },
    midiSrc, nil, nil, nil
);
nOnResp = NoteOnResponder({|src, chan, num, val|
    //	[src,chan,num,val].postln;
    case
    {num == 46} {{btSynthList[0].valueAction_(1-btSynthList[0].value)}.defer}
    {num == 43} {{btSynthList[1].valueAction_(1-btSynthList[1].value)}.defer}
    {num == 56} {{btSynthList[2].valueAction_(1-btSynthList[2].value)}.defer}
    {num == 57} {{btSynthList[3].valueAction_(1-btSynthList[3].value)}.defer}
    },
    midiSrc, nil, nil, nil
);

//effect synth goes to channels [0,1]
effSynth= Synth(effSynthName, [\inBus, params[\wetBus], \outBus, params[\effBus]]);
//control rate synths
synthCtrlArgs.size.do({ |i|
	synthCtrl.add(Synth(synthCtrlArgs[i][0].asSymbol, [\outbus, synthCtrlArgs[i][1]]));
});

win.refresh;
win.front;

// Shutting down.
shutDown = {
    // Free synths.
	synthList.size.do({ |i|
		synthList[i].set(\gate, 0);
		synthCtrl[i].free;
	});
	effSynth.free;
	ccResp.remove;

    // Close window.
    if (win.isClosed.not) {win.close};

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