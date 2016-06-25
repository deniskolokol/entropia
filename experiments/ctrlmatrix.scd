// XXX - figure out and inmplement a concept of insert channels!
//       Ideally use output of one channel as input to the other one
//       (for output use channel numbers (1..8 + 'main') instead of bus numbers
//       and make it drag and drop in the GUI).
//       Problem: how to combine it with a flexible spatial settings that
//       takes place upon a group creation?
// XXX - consider: for .ar GUI knobs and sliders control one set of params,
//       while another set is available for the modulation with .kr

(
var krN, arN;
var matrix, matrixPast, initMatrix;
var synthOnOff, synthSend, synthReRoute, synthShortName,
groupInit, modulatorInit, groupFree, sendToSrv, getSpatial;
var paramDefs, scopeParam, valAsApec,
paramsAr, controlsAr, controlsKr, defaultParams,
synthsAr, synthsKr, synthNamesAr, synthNamesKr,
krInputs;
var clipInc;
var outBus=(0..29),
internalBus=(30..Server.default.options.numAudioBusChannels-1),
krBus = (0..Server.default.options.numControlBusChannels-1);
var win;
var paneMatrix, paneLeftSide, paneSettings, paneUnits, paneUnit,
paneArSynths, paneKrSynths, paneGrid, pane,
paneConnections, matrixButtons;
var synthType, synthIn, synthOut;
var btPanic, master, crossfade;
var paneWidth, paneHeight;
var button, buttonCheckbox, buttonCheckboxFlow, knob, slider,
dropdown, compView, compFixed, compViewFlow, levelInd;
var colorBtUp=Color.grey(0.6), colorBtDown=Color.blue,
colorBtLabel=Color.grey(0.2), colorPane=Color.grey(0.3),
colorStringBg = Color.grey(alpha:0.1), colorString=Color(0.8, 0.8, 0.8);
var parmName, parmVal;
var clean;
var envi;

// constants
var s__SYNTHNAME = "ms__(a|k|p|r|s|u){1}__[a-zA-Z0-9]+";
var ar__ROOT_NODE = s.nextNodeID; // root ID for generators & processors
var kr__ROOT_NODE = s.nextNodeID; // root IDs for modulators

// initialise server groups
s.sendMsg("/g_new", ar__ROOT_NODE, 0, 1);
s.sendMsg("/g_new", kr__ROOT_NODE, 0, 1);

// environment configuration
envi = (
    currentDir: PathName(thisProcess.nowExecutingPath).pathOnly,
    inbus: 12,
    outbus: 0,
    mainInput: 20,
    mainOutput: 0,
    route: 30,
    surround: "ambisonic",
    depth: 3.5,
    speakers: (
        items: List[
            (dist: 1, azim: -0.25pi, elev: -0.1pi),
            (dist: 1, azim: -0.75pi, elev: -0.1pi)
        ],
        maxDist: 1,
        collectAzim: { |self| all{: sp.azim, sp <- self.items} },
        collectDist: { |self| all{: sp.dist, sp <- self.items} },
        collectElev: { |self| all{: sp.elev, sp <- self.items} },
        removeSpeaker: { |self, index|
            if ((self.items.size - 1) < 2) {
                postf("WARNING! Cannot remove speaker %! At least two speakers should be defined!", index+1);
            } {
                self.items.pop(index);
            }
        },
    ),
    synths: (
        ms__a__sawy: (attenuate: 0.05),
        ms__a__electro: (attenuate: 0.5),
        ms__a__wind: (attenuate: 0.05),
        ms__a__loop: (attenuate: 1),
    )
);

// synths and params
paramDefs = (
    azimuth:   ( label: "azi",    minval: -1pi,   maxval: 1pi,    step: 0.01, default: 0   ),
    distance:  ( label: "dist",   minval: 0,      maxval: 2.sqrt, step: 0.01, default: 0   ),
    elevation: ( label: "elev",   minval: -0.5pi, maxval: 0.5pi,  step: 0.01, default: 0   ),
    velocity:  ( label: "vel",    minval: 0,      maxval: 1,      step: 0.01, default: 0   ),
    depth:     ( label: "depth",  minval: 1,      maxval: 10,     step: 0.1,  default: 5   ),
    offset:    ( label: "offset", minval: 0,      maxval: 127,    step: 1,    default: 36  ),
    cutoff:    ( label: "cutoff", minval: 0,      maxval: 10000,  step: 10,   default: 1000),
    rq:        ( label: "RQ",     minval: 0.01,   maxval: 0.9,    step: 0.01, default: 0.5 ),
    freq:      ( label: "freq",   minval: 0.01,   maxval: 10000,  step: 0.01, default: 440 ), // 0.001..1.000 | 1..10000
    scope:     ( label: "scope",  minval: 0,      maxval: 1,      step: 0.01, default: 0   ), // scopes add and mul
    mul:       ( label: "mul",    minval: 0,      maxval: 1,      step: 0.01, default: 1   ),
    amp:       ( label: "amp",    minval: 0,      maxval: 1,      step: 0.01, default: 1   ),
    add:       ( label: "add",    minval: 0,      maxval: 10,     step: 0.01, default: 0   ),
);
// modulatable
paramsAr = #[\azimuth, \distance, \elevation, \velocity];
paramsAr = #[\cutoff, \distance, \elevation, \velocity]; // TEST!!
// controllable via GUI
// XXX - \amp is controlled by ambisonic or on mixing board. substitute with compression(?)
controlsAr = #[\offset, \cutoff, \rq, \amp];
controlsKr = #[\freq, \scope, \mul, \add];
synthNamesAr = envi.synths.keys.asArray;
synthNamesKr = #["ms__k__sin", "ms__k__saw", "ms__k__tri",
    "ms__k__lfnoise0", "ms__k__lfnoise1", "ms__k__lfnoise2",
    "ms__k__clipnoise", "ms__k__stepnoise"];
synthsAr = all {:
    (
        name: syn.asString,
        params: controlsAr ++ paramsAr
    ),
    syn <- synthNamesAr
};
synthsKr = all {:
    (
        name: syn.asString,
        params: controlsKr
    ),
    syn <- synthNamesKr
};

// initialize main matrix container
#krN, arN = [8, 8];

defaultParams = { |synthname|
    // Fills up a dictionary with default params for synth name.
    var params, result, val;

    // fill list of param names
    (synthsAr ++ synthsKr).do { |def|
        if (def.name.asSymbol == synthname.asSymbol) {
            params = def.params;
        }
    };

    // find and fill initial values of params
    if (params.isNil.not) {
        result = ();
        params.do { |parm, i|
            val = paramDefs.atFail(parm, {(default: 0)})[\default];
            result[parm] = val
        }
    };

    result
};

initMatrix = {(
    ar: Array.fill(arN, { |i|
        (
            synthname: synthNamesAr[i % synthsAr.size],
            inbus: envi.inbus,
            outbus: envi.outbus,
            node: 0,
            active: false,
            params: defaultParams.(synthNamesAr[i % synthsAr.size])
        )
    }),
    kr: Array.fill(krN, { |i|
        (
            synthname: synthNamesKr[i % synthsKr.size],
            inbus: 0,
            outbus: krBus[i],
            node: 0,
            active: false,
            params: defaultParams.(synthNamesKr[i % synthsKr.size])
        )
    })
)};
matrix = initMatrix.();
matrixPast = initMatrix.();

//
// XXX - finish and test it!
//     - create a new one for frequency (0.01..1.000 | 1..100)
scopeParam = { |scope, val, param|
    var min, max, out;
    min = scope.lincurve(0.00, 1.00, 0.00, 200.00, 4).round(0.01);
    max = scope.lincurve(0.00, 1.00, 0.10, 10000.00, 4).round(0.01);
    out = val.linlin(paramDefs[param][\minval], paramDefs[param][\maxval], min, max);
    out
};


valAsApec = { |param|
    // converts param dictionary to ControlSpec
    param.atFail(\spec, {
        [
            param.atFail(\minval, {0}), param.atFail(\maxval, {1}),
            param.atFail(\warp, {\lin}),
            param.atFail(\step, {0}),
            param.atFail(\default, {0})
        ]
    }).asSpec
};


clipInc = { |in=0, step=1, lo=0, hi=inf|
    // Increments `in` until `in + step` reaches `hi`, then resets to `lo`.
    ((in + step).clip(lo, hi) % hi).clip(lo, hi)
};


// synth functions
synthShortName = { |name|
    // Short synth name starts from 7th symbol (after "\ms__?__").
    if (s__SYNTHNAME.matchRegexp(name.asString)) {
        name[7..]
    } {
        name
    };
};


getSpatial = {
    // full spatial name
    format("ms__s__%%", envi.surround, envi.speakers.items.size)
};


sendToSrv = { |messages, time=0.1|
    // Sends arbitrary messages to the server with lag.
    messages.do {|msg| msg.postln}; // XXX
    s.listSendBundle(time, messages)
};


modulatorInit = { |synth, bufnum, inbus, outbus, params|
    // Creates a .kr synth on Server. Doesn't need spatializer.
    // Returns nil, if outbus is not given (.kr doesn't make
    // sense without outbus).
    var messages, node = s.nextNodeID;
    params = params ? [];
    if (inbus.isNil.not) {
        params = params ++ [\inbus, inbus]
    };
    if (outbus.isNil.not) {
        params = params ++ [\outbus, outbus];
        messages = [
            ["/s_new", synth, node, 0, kr__ROOT_NODE],
            ["/n_set", node] ++ (params ? [])
        ];
        sendToSrv.(messages);
    } {
        node = nil
    };
    node
};


groupFree = { |node, release=2|
    // Releases all synths from group, wait until released, then remove
    // group node from server.
    Routine({
        [
            ["/n_set", node, \rel, release ? 2.rand, \gate, 0],
            ["/n_free", node]
        ].do { |msg|
            s.listSendMsg(msg);
            release.wait;
        }
    }).play;
};


groupInit = { |synth, bufnum, inbus, outbus, spatial, params|
    // Creates new group on Server, inserts synth and spatializer into it.
    // Assigns internal bus for routing: each group of synth and its
    // spatializer should have a separate routing bus for spatialization to
    // take place individually.
    var node, spatializer, generator, messages, synthPar;
    node = s.nextNodeID;
    inbus = inbus ? envi.mainInput;
    outbus = outbus ? envi.mainOutput;
    envi.route = clipInc.( // calculate and save for subsequent assignments
        envi.route ?? internalBus[0],
        lo: internalBus[0],
        hi: internalBus[1]
    );
    spatial = spatial ? getSpatial.();
    spatializer = [
        "/s_new", spatial, s.nextNodeID, 1, node, // spatializer goes to a new group's tail
        \route, envi.route,
        \outbus, outbus,
        \depth, envi.depth
    ] ++ [\maxDist, envi.speakers.maxDist]
    ++ [\speakerAzim, $[] ++ envi.speakers.collectAzim() ++ [$]]
    ++ [\speakerDist, $[] ++ envi.speakers.collectDist() ++ [$]]
    ++ [\speakerElev, $[] ++ envi.speakers.collectElev() ++ [$]];

    generator = [
        "/s_new", synth, s.nextNodeID, 0, node, // synth goes to a new group's head
        \inbus, inbus,
        \route, envi.route,
        \bufnum, bufnum
    ] ++ (params ? []);
    messages = [
        ["/error", 0], // turn errors off locally
        ["/g_new", node, 0, ar__ROOT_NODE],
        spatializer,
        generator
    ];
    sendToSrv.(messages);
    node // return ID of the Group created
};


synthOnOff = { |arKr, pos, params|
    // Switches synth ON, if its \active in the matrix, OFF otherwise.
    // Returns Node ID.
    var def, parm, node=0;
    def = matrix[arKr][pos];
    if (def.active) {
        parm = merge( // update default params by params from matrix
            defaultParams.(def[\synthname]),
            def[\params] ? Dictionary[],
            { |a, b| b }
        );
        parm = merge( // update parm by `params`
            parm,
            params ? Dictionary[],
            { |a, b| b }
        );
        def[\params] = parm; // save updated params to matrix
        if (arKr == 'ar') {
            node = groupInit.(def[\synthname],
                inbus:def[\inbus],
                outbus:def[\outbus],
                params:parm.getPairs
            );
        } {
            node = modulatorInit.(def[\synthname],
                inbus:def[\inbus],
                outbus:pos,
                params:parm.getPairs
            );
        };
    } {
        groupFree.(def[\node], 0.5)
    };
    def[\node] = node;
};


synthSend = { |arKr, pos, params|
    // Sends params to the given node, specified in matrix.
    // Param's value can either be set directly or "mapped" to a .kr bus.
    // If param is mapped, its value is String formatted as follows:
    // "kr_<x>", where "x" is a .kr bus number.
    var def, paramsSend, paramsMap;

    def = matrix[arKr][pos];
    params = params ? def.params;
    if (def.active) {
        paramsSend = params.reject { |item| item.asString.beginsWith("kr_") };
        if (paramsSend.size > 0) {
            ["paramsSend", paramsSend].postln;
            sendToSrv.([["/n_set", def[\node]] ++ paramsSend.getPairs]);
        };
        paramsMap = params.select { |item| item.asString.beginsWith("kr_") };
        if (paramsMap.size > 0) {
            ["paramsMap", paramsMap].postln;
            paramsMap = paramsMap.collect { |item| item.asString[3..] };
            sendToSrv.([["/n_map", def[\node]] ++ paramsMap.getPairs]);
        };
    };
};

synthReRoute = { |arKr, pos, route|
    var def = matrix[arKr][pos];
    if (def.active) {
        sendToSrv.([["/n_set", def[\node]] ++ route])
    };
};


// interface
win = Window("ctrl matrix", Window.screenBounds.width@Window.screenBounds.height);

paneWidth = { |par, scale=1| (par.bounds.width * scale - 6).floor };
paneHeight = { |par, scale=1| (par.bounds.height * scale - 6).floor };
button = { |par, label, action, scaleH=1, scaleW=1, colorLabel, colorBg|
    colorLabel = colorLabel ? colorBtLabel;
    colorBg = colorBg ? colorBtUp;
    Button(par, paneWidth.(par, scaleW)@paneHeight.(par, scaleH)).states_([
        [label, colorLabel, colorBg]
    ])
    .font_(Font("Helvetica", 12))
    .action_({ |bt| action.(bt.value) })
    .canFocus_(false);
};
buttonCheckbox = { |par, label, action, value, bounds, colorUpLb, colorUpBg, colorDwLb, colorDwBg|
    var labelUp, labelDw;
    colorUpLb = colorUpLb ? colorBtLabel;
    colorUpBg = colorUpBg ? colorBtUp;
    colorDwLb = colorDwLb ? colorString;
    colorDwBg = colorDwBg ? colorBtDown;
    if (label.class == Array) {
        #labelUp, labelDw = label
    } {
        #labelUp, labelDw = [label, label]
    };
    Button(par, bounds).states_([
        [labelUp, colorUpLb, colorUpBg],
        [labelDw, colorDwLb, colorDwBg]
    ])
    .value_(value)
    .action_({ |bt| action.(bt.value) })
    .font_(Font("Helvetica", 12))
    .canFocus_(false);
};
buttonCheckboxFlow = { |par, label, action, value, scaleH=1, scaleW=1, colorUpLb, colorUpBg, colorDwLb, colorDwBg|
    var bounds = paneWidth.(par, scaleW)@paneHeight.(par, scaleH);
    buttonCheckbox.(par, label, action, value, bounds, colorUpLb, colorUpBg, colorDwLb, colorDwBg);
};
knob = { |par, label, spec, action, default=0, layout='vert', scaleW=1, scaleH=1|
    var knobWidth=paneWidth.(par, scaleW), knobHeight=paneHeight.(par, scaleH);
    if (layout != 'vert') {
        knobWidth = paneWidth.(par, scaleW) - 10;
        knobHeight = paneHeight.(par, scaleH);
    };
    EZKnob(par, knobWidth@knobHeight, label, spec,
        { |ez| action.(ez.value) }, default,
        layout: layout
    )
    .font_(Font("Helvetica", 12))
    .setColors(stringColor: Color.white)
};
slider = { |par, label, spec, action, default, layout='horz', scale=1|
    var labelWidth=0, numberWidth=45;
    var bounds=paneWidth.(par)@20;
    if (label.isNil.not) { labelWidth = label.size * 5 };
    if (layout == 'horz') {
        bounds = (paneWidth.(par, scale))@20;
        numberWidth = 30;
    } {
        bounds = 30@(paneHeight.(par, scale))
    };
    if (default.isNil) { default = spec.default };
    EZSlider(par, bounds, label, spec, { |ez| action.(ez.value) }, default,
        labelWidth: labelWidth, numberWidth: numberWidth, layout: layout)
    .font_(Font("Helvetica", 12))
    .setColors(stringColor: Color.white)
};
dropdown = { |par, label, items, action, initVal=0, scale=1|
    var labelWidth=0;
    if (label.isNil.not) { labelWidth = label.size * 9};
    EZPopUpMenu(par,
        bounds: paneWidth.(par, scale)@20,
        label: label,
        items: items,
        globalAction: action,
        initVal: initVal,
        labelWidth: labelWidth
    )
    .font_(Font("Helvetica", 11))
    .setColors(colorStringBg, colorString)
};
compView = { |par, color, scaleW=1, scaleH=1|
    if (color.isNil) { color = colorPane };
    CompositeView(par,
        paneWidth.(par, scaleW)@paneHeight.(par, scaleH)
    ).background_(color);
};
compFixed = { |par, color, bounds|
    if (color.isNil) { color = colorPane };
    if (bounds.isNil) { bounds = Rect(1, 1, par.bounds.width-2, par.bounds.height-2) };
    CompositeView(par, bounds).background_(color);
};
compViewFlow = { |par, color, scaleW=1, scaleH=1|
    var vw;
    vw = compView.(par, color, scaleW, scaleH);
    vw.decorator = FlowLayout(vw.bounds);
    vw
};
levelInd = { |par, default=0, scaleW=1, scaleH=1|
    LevelIndicator(par, paneWidth.(par, scaleW)@paneHeight.(par, scaleH))
    .background_(Color.clear)
    .value_(default).warning_(0.7).critical_(0.9)
};

// panels
paneMatrix = CompositeView(win,
    win.bounds.width@win.bounds.height
).background_(Color.grey(0.7));
paneMatrix.decorator = FlowLayout(paneMatrix.bounds);

paneLeftSide = compViewFlow.(paneMatrix, scaleW: 0.4).background_(Color.red);
paneSettings = compViewFlow.(paneLeftSide, scaleH:0.4);
master = slider.(paneSettings, "Master", \db.asSpec,
    { |sl| s.volume.volume = sl.value }, scale:0.75
);
crossfade = slider.(paneSettings, "X-Fade",
    [0.5, 5, \lin, 0.1, 2].asSpec, scale:0.75
);
btPanic = button.(paneSettings, "PANIC",
    { |val| val.postln},
    0.07, 0.25, Color.white, Color.red
);

paneArSynths = compViewFlow.(paneMatrix, scaleW: 0.6);
paneConnections = compViewFlow.(paneArSynths, scaleH: 0.05, color: Color.grey(0.7));
// .ar synth panel and controls
paneUnits = compViewFlow.(paneArSynths);
arN.do { |i|
    var paneKnobs, paneSlid;
    var paneUnit, paneControls, paneMatrixControls, paneMatrix;
    var cellSize=1;

    // bookmark
    // RE-WORK!
    paneUnit = compView.(paneUnits, scaleW: arN.reciprocal+0.002);
    cellSize = (paneUnit.bounds.width / paramsAr.size) - 3;

    paneControls = compFixed.(
        paneUnit,
        bounds:Rect(1,
            1,
            paneUnit.bounds.width-2,
            paneUnit.bounds.height * 0.65
        ),
    );
    // synth
    pane = compViewFlow.(paneControls, scaleW: 0.9);

    // .ar synth
    synthIn = dropdown.(pane, "",
        items: internalBus,
        action: { |dd| matrix[\ar][i][\inbus] = dd.value },
    scale: 0.5);
    synthOut = dropdown.(pane, "",
        items: outBus,
        action: { |dd| matrix[\ar][i][\outbus] = dd.value },
    scale: 0.5);
    synthType = dropdown.(pane,
        items: all {:synthShortName.(n[\name]), n <- synthsAr },
        initVal: synthNamesAr.indexOf(matrix.ar[i][\synthname]),
        action: { |dd|
            matrix.ar[i][\synthname] = synthsAr[dd.value][\name];
        },
    );
    buttonCheckboxFlow.(pane, "ON",
        { |btn| matrix[\ar][i][\active] = btn.value.booleanValue },
        scaleW: 0.5, scaleH: 0.05
    );
    buttonCheckboxFlow.(pane, "REC", { |val| val.postln },
        scaleW: 0.5, scaleH: 0.05, colorDwLb: Color.white, colorDwBg:Color.red
    );

    // inserts
    4.do { |i|
        buttonCheckbox.(pane, (i+1).asString,
            { |bt, nt| bt.postln },
            bounds:Rect(
                i * cellSize,
                20 * 0.5 + 2,
                20,
                20
            ),
            colorUpLb: Color.white,
            colorUpBg: colorPane,
            colorDwLb: colorPane,
            colorDwBg: Color.grey(0.8)
        );
    };

    paneKnobs = compViewFlow.(pane, scaleW: 0.6, scaleH: 0.7);
    controlsAr[0..2].do { |key|
        knob.(paneKnobs, paramDefs[key][\label],
            spec: valAsApec.(paramDefs[key]),
            action: { |kn| try { matrix.ar[i][\params][key] = kn.value }},
            layout: \vert, scaleW: 1, scaleH: 0.336
        );
    };
    paneSlid = compViewFlow.(pane, scaleW: 0.4, scaleH: 0.7);
    slider.(paneSlid, paramDefs[controlsAr[3]][\label],
        spec: valAsApec.(paramDefs[controlsAr[3]]),
        action: { |kn| try { matrix.ar[i][\params][controlsAr[3]] = kn.value }},
    layout: 'vert');
    // level meter
    // XXX - ugly! re-work!
    pane = compView.(paneControls, scaleW: 0.1);
    levelInd.(pane, 0.5);

    // params controllable by matrix
    paneMatrixControls = compFixed.(
        paneUnit,
        bounds:Rect(1,
            paneControls.bounds.height + 2,
            paneUnit.bounds.width - 2,
            cellSize * 1.6
        ),
    );
    buttonCheckbox.(paneMatrixControls, "<>",
        { |bt, nt| bt.postln }, // XXX - When ON, it affects coresponding manually controlled param!
        bounds:Rect(1, 1, paneMatrixControls.bounds.width-1, cellSize * 0.5),
        colorUpLb: Color.white,
        colorUpBg: colorPane,
        colorDwLb: colorPane,
        colorDwBg: Color.grey(0.8)
    );
    paramsAr.do { |parm, i|
        buttonCheckbox.(paneMatrixControls, parm.asString[..3],
            { |bt, nt| bt.postln },
            bounds:Rect(
                i * (cellSize + 3),
                cellSize * 0.5 + 2,
                cellSize + 2,
                cellSize
            ),
            colorUpLb: Color.white,
            colorUpBg: colorPane,
            colorDwLb: colorPane,
            colorDwBg: Color.grey(0.8)
        );
    };

    // matrix switches (buttons)
    paneMatrix = compFixed.(
        paneUnit,
        bounds:Rect(1,
            (paneControls.bounds.height + paneMatrixControls.bounds.height) + 4,
            paneUnit.bounds.width - 2,
            paneUnit.bounds.height - paneControls.bounds.height - paneMatrixControls.bounds.height,
        ),
    );
    krN.do { |krInd|
        paramsAr.size.do { |arParamInd|
            buttonCheckbox.(paneMatrix, ["-", "|"],
                { |bt, nt| bt.postln },
                bounds:Rect(
                    arParamInd * (cellSize + 3) + 1,
                    krInd * (cellSize + 3),
                    cellSize,
                    cellSize
                ),
                colorUpBg: colorPane,
                colorDwBg: Color.white,
                colorDwLb: Color.red,
            );
        };
    };
};


paneKrSynths = compViewFlow.(paneLeftSide, scaleH: 0.6);
// .kr synth panel and controls
8.do { |i|
    paneUnit = compViewFlow.(paneKrSynths, scaleH: 0.125);
    pane = compViewFlow.(paneUnit, scaleW: 0.95);

    // .kr synth
    synthType = dropdown.(pane,
        // XXX - this can be extended with "external" and OSC funcs
        //       including those that carry generators Amplitude.kr
        items: all {:synthShortName.(n[\name]), n <- synthsKr },
        initVal: synthNamesKr.indexOf(matrix.kr[i][\synthname]),
        action: { |dd|
            matrix.kr[i][\synthname] = synthsKr[dd.value][\name];
        },
        scale: 0.15
    );
    knob.(pane, paramDefs[\scope][\label], // scope
        spec: valAsApec.(paramDefs[\scope]),
        action: { |kn| try { matrix.kr[i][\params][\scope] = kn.value }},
        layout: \horz, scaleW: 0.15
    );
    controlsKr[2..3].do { |key|
        knob.(pane, paramDefs[key][\label],
            spec: valAsApec.(paramDefs[key]),
            action: { |kn|
                try {
                    matrix.kr[i][\params][key] = scopeParam.(
                        scope: matrix.kr[i][\params][\scope],
                        val: kn.value,
                        param: key
                    );
                };
            },
            layout: \horz, scaleW: 0.15
        );
    };
    slider.(pane, paramDefs[controlsKr[0]][\label],
        spec: valAsApec.(paramDefs[controlsKr[0]]),
        action: { |kn| try { matrix.kr[i][\params][controlsKr[0]] = kn.value }},
        scale: 0.15);
    buttonCheckboxFlow.(pane, "ON",
        { |btn| matrix[\kr][i][\active] = btn.value.booleanValue },
        scaleW:0.11
    );
    button.(pane, "RES", { |val| val.postln }, scaleW:0.11, scaleH:0.6);
    // levelInd.(paneUnit, 0.5, scaleW:0.05);
};

// XXX
// WARNING! Move this and adapt to "matrix switches (buttons)"
//
// paneGrid = compViewFlow.(paneMatrix, color: Color.white, scaleW: 0.8, scaleH: 0.6);
// matrixButtons = List.new;
// krN.do { |krInd|
//     arN.do { |arInd|
//         pane = compView.(paneGrid, scaleW: 0.126, scaleH: 0.127);
//         paramsAr.size.do { |arParamInd|
//             matrixButtons.add(
//                 buttonCheckbox.(pane, "_",
//                     { |bt, nt|
//                         parmName = paramsAr[arParamInd];
//                         if (bt.value.booleanValue) {
//                             parmVal = "kr_" ++ krInd.asString; // ON - modulate
//                             krN.collect { |j| // other .kr modulations of the current .ar synth - OFF
//                                 (j * (arN * paramsAr.size)) + (paramsAr.size * arInd + arParamInd)
//                             }.do { |krI|
//                                 if (
//                                     // XXX - move it to a separate function!
//                                     matrixButtons[
//                                         (paramsAr.size * arInd + arParamInd) + (krInd * paramsAr.size * arN) // current index
//                                     ] != matrixButtons[krI]
//                                 ) {
//                                     matrixButtons[krI].value = 0;
//                                 }
//                             };
//                         } {
//                             parmVal = paramDefs[parmName][\default]; // OFF - default param
//                         };
//                         try { // to set value param
//                             matrix.ar[arInd][\params][parmName] = parmVal;
//                         };
//                     },
//                     bounds:Rect(
//                         (arParamInd * 25) + (arParamInd * pane.bounds.width * 0.1) + 6,
//                         (pane.bounds.height * 0.35), 25, 25
//                     )
//                 );
//             );
//         };
//     }
// };

win.view.keyDownAction = { arg view, char, modifiers, unicode, keycode;
    [char, modifiers, unicode, keycode].postln;
    case
    { keycode == 8 } { // C
        if (modifiers == 262144) { // Ctrl + C
            clean.();
        }
    }
    { keycode == 3 } { // F
        if (modifiers == 262144) { // Ctrl + F
            if (win.bounds == Window.screenBounds) {
                win.endFullScreen
            } {
                win.fullScreen
            }
        }
    }
    { keycode == 53 } { // ESC
        if (win.bounds == Window.screenBounds) {
            win.endFullScreen
        }
    }
    { keycode == 34 } { // I
        if (modifiers == 262144) { // Ctrl + I
            matrix.keysValuesDo { |arKr, synths, i|
                postf("\n%:\n", arKr);
                synths.do { |syn, j| syn.postln };
            }
        }
    }
};

{ // global app clock with resolution 100 milliseconds (0.1 of a second)
    var defPast, synthName;
    while { win.isClosed.not } {
        matrix.keys.do { |arKr|
            matrix[arKr].do { |def, pos|
                defPast = matrixPast[arKr][pos];

                if (def.active != defPast.active) {
                    synthOnOff.(arKr, pos);
                    defPast.active = def.active;
                };
                if (def.synthname != defPast.synthname) {
                    if (def.active) {
                        groupFree.(def.node, crossfade.value); // switch OFF old synth
                        synthOnOff.(arKr, pos, [\att, crossfade.value]); // then turn ON a new one
                    };
                    defPast.synthname = def.synthname;
                };
                def.params.keysValuesDo { |key, val|
                    if (defPast.params[key] != val) {
                        synthSend.(arKr, pos, Dictionary[key -> val]);
                        defPast.params[key] = val;
                    }
                };
                if (arKr == \ar) {
                    [\inbus, \outbus].do { |bus|
                        if (def[bus] != defPast[bus]) {
                            synthReRoute.(arKr, pos, [bus, def[bus].asInteger]);
                            defPast[bus] = def[bus]
                        };
                    }
                }
            };
        };
        0.1.wait;
    }
}.fork(AppClock);

win.front;

// clean everything on exit
clean = {
    win.close;
};

"Loading synth definitions...".postln;
if (this.executeFile(envi.currentDir +/+ "synthdef.scd").isNil.not) {
    postf("OK\n\n")
};

CmdPeriod.doOnce({
    clean.();
});
)