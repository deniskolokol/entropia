// test kr unit deactivate
n = EntroUnit.new(\sr__e__pulse, 20, 0)
n.activate([\amp, 0.5, \velocity, 0.5, \distance, 0.2])
k = EntroUnit.new(\sr__k__sine, out:2)
k.sendParams([\lfo, 0.5.rand, \min, 5, \max, 75]);
k.activate
n.mapParam(\offset, k);
k.deactivate
n.deactivate
Entropia.removeAll
// end - test kr unit deactivate

(
var colorBtUp=Color.grey(0.6),
    colorBtDown=Color.blue,
    colorBtLabel=Color.grey(0.2),
    colorStringBg=Color.grey(alpha:0.1),
    colorString=Color(0.8, 0.8, 0.8);
var color=Color.grey(0.2),
    highlighted=Color.grey(0.8), // Color.white
    transparent=Color.grey(alpha:0.01),
    font=Font("Monaco", 10),
    fontSmall=Font("Monaco", 8),
    fontLarge=Font("Monaco", 12),
    fontGiant=Font("Monaco", 20),
    fontColor=Color.grey(0.9);
var paneWidth = { |par, scale=1| (par.bounds.width * scale - 6).floor };
var paneHeight = { |par, scale=1| (par.bounds.height * scale - 6).floor };
var compView = { |par, color, scaleW=1, scaleH=1|
    if (color.isNil) { color = transparent };
    CompositeView(par,
        paneWidth.(par, scaleW)@paneHeight.(par, scaleH)
    ).background_(color);
};
var compViewFlow = { |par, color, margin, gap, scaleW=1, scaleH=1|
    var vw;
    if (color.isNil) { color = transparent };
    vw = compView.(par, color, scaleW, scaleH);
    vw.decorator = FlowLayout(vw.bounds, margin ? 1@1, gap ? 1@1);
    vw
};
var knob = { |par, label, spec, action, initVal, layout='vert', bounds|
    if (initVal.isNil) { initVal = spec.default };
    EZKnob(par, bounds, " " ++ label.asString, spec,
        { |ez| action.(ez.value) },
        initVal, layout: layout
    )
    .setColors(numBackground:Color.grey, numNormalColor:Color.yellow)
    .font_(font)
};
var slider = { |par, label, spec, action, initVal, layout='horz', scaleW=1, scaleH=1, numberWidth=45, margin|
    var labelWidth=0;
    var bounds=paneWidth.(par)@20;
    margin = margin ? 1@1;
    if (label.isNil.not) { labelWidth = label.size * 5 };
    bounds = (paneWidth.(par, scaleW))@(paneHeight.(par, scaleH));
    if (layout == 'horz') { numberWidth = 30 } { numberWidth = 45 };
    if (initVal.isNil) { initVal = spec.default };
    EZSlider(
        par, bounds, label, spec,
        { |ez| action.(ez.value) },
        initVal,
        labelWidth: labelWidth, numberWidth: numberWidth, layout: layout, margin: margin
    )
    .setColors(numBackground:Color.grey, numNormalColor:Color.yellow)
    .font_(font)
};
var dropdown = { |par, label, items, action, initVal=0, scale=1|
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
};
var button = { |par, label, action, scaleH=1, scaleW=1, colorLabel, colorBg|
    colorLabel = colorLabel ? colorBtLabel;
    colorBg = colorBg ? colorBtUp;
    Button(par, paneWidth.(par, scaleW)@paneHeight.(par, scaleH)).states_([
        [label, colorLabel, colorBg]
    ])
    .font_(Font("Helvetica", 12))
    .action_({ |bt| action.(bt.value) })
    .canFocus_(false);
};
var levelInd = { |par, default=0, scaleW=1, scaleH=1|
    LevelIndicator(par, paneWidth.(par, scaleW)@paneHeight.(par, scaleH))
    .background_(Color.clear)
    .value_(default)
    .warning_(0.7)
    .critical_(0.9)
    .drawsPeak_(true)
};

// make GUI for a single audio rate unit
var makeGuiAr = { |unit, parent|
    var ctrl, modul;
    var scaleW = 244 / parent.bounds.width;
    var panelMain = compViewFlow.(parent, scaleW:0.25);
    var panelLeft = compViewFlow.(panelMain, scaleW:0.9);
    var panelRight = compViewFlow.(panelMain, scaleW:0.13);
    var panelLeftTop = compViewFlow.(panelLeft, scaleH:0.9);
    var panelLeftBottom = compViewFlow.(panelLeft, scaleH:0.13);
    var panelLeftTopLeft = compViewFlow.(panelLeftTop, scaleW:0.82);
    var panelLeftTopRight = compViewFlow.(panelLeftTop, scaleW:0.2);
    var panel;
    var synthList, envSet;

    // [parent.bounds.width, panelMain.bounds.width].postln;

    // synth name
    synthList = EntroSynthDefs.params.keys.asArray;
    panel = compViewFlow.(panelLeftTopLeft, scaleH:0.1);
    dropdown.(panel,
        items: all {:Entropia.synthnameShort(y), y <- synthList},
        initVal: synthList.indexOf(unit.synthname),
        action: { |dd| dd.postln },
    );

    // inbus and outbus
    panel = compViewFlow.(panelLeftTopLeft, scaleH:0.1);
    dropdown.(panel, "In",
        items: (0..29), // XXX temp - should be param in Entropia
        initVal: unit.inbus,
        action: { |dd| unit.inbus = dd.value },
        scale: 0.5
    );
    dropdown.(panel, "O",
        items: (0..9), // XXX temp - should be param in Entropia
        initVal: unit.outbus,
        action: { |dd| unit.outbus = dd.value },
        scale: 0.5
    );

    // envelope
    unit.randomizeEnv;
    panel = compViewFlow.(panelLeftTopLeft, scaleH:0.5);
    EnvelopeView(panel, panel.bounds.width@(panel.bounds.height*0.5))
        .drawLines_(true)
        .selectionColor_(Color.red)
        .drawRects_(true)
        .resize_(5)
        .step_(0.05)
        .strokeColor_(Color.white)
        .background_(transparent)
        .action_({arg b; [b.index, b.value].postln})
        .thumbSize_(5)
        .setEnv(unit.env);

    // XXX - finish it
    // effects
    unit.insert.do { |i| // XXX
        slider.(panel, i, \unipolar.asSpec,
            { |v| v.postln },
            layout: \horz,
            scaleH: 0.2
        );
    };

    // first three params
    panel = compViewFlow.(panelLeftTopLeft, scaleH:0.4);
    // params, whose indexes bigger than 8, unavailable in GUI
    // 1-4 controllable params: available for external control via MIDI
    unit.params[..3*2-1].pairsDo { |parmName, val|
        knob.(
            panel, // XXX TEMP
            parmName, Entropia.specs[parmName],
            { |v| unit.sendParams([parmName, v]) },
            val,
            bounds:50@90
        );
    };

    // last param
    unit.params[6..7].pairsDo { |parmName, val|
        slider.(
            panelLeftTopRight,
            parmName, Entropia.specs[parmName],
            { |v| unit.sendParams([parmName, v]) },
            val,
            layout: \vert
        );
    };
    // 5-8 modulatable params: can be modulated by .kr
    unit.params[4*2..8*2-1].pairsDo { |parmName, val|
        button.(panelLeftBottom, parmName.asString[..5],
            { |bt, nt| bt.postln },
            scaleW: 0.275
        );
    };

    // level indicator
    levelInd.(panelRight, 0.4);

    // TODO
    // double click on the area:
    // unit.activate([\amp, 0.5, \velocity, 0.5, \distance, 0.2]);
};

var makeGuiKr = { |unit, parent|
    // XXX
};

var makeGui = { |unit, parent|
    unit.type.switch(
        \ar, {
            makeGuiAr.(unit, parent)
        },
        \kr, {
            makeGuiKr.(unit, parent)
    })
};

var arUnits = [
    EntroUnit.new(\sr__e__pulse, 20, 0),
    EntroUnit.new(\sr__e__plane, 20, 0),
    EntroUnit.new(\sr__e__sawy, 20, 0),
    EntroUnit.new(\sr__e__dust, 20, 0),
];
w = Window('matrix', Rect(700, 800, 1000, 300));
w.view.decorator = FlowLayout(w.bounds);
arUnits.do { |unit|
    makeGui.(unit, w, 0.25);
};
w.front;

CmdPeriod.doOnce({
    w.close;
    n.remove;
});
)


n = EntroUnit.new(\sr__e__pulse, 20, 0)

n.params // key value pairs of params in the order of appearance
n.activate([\amp, 0.5, \velocity, 0.5, \distance, 0.2])
n.sendParams([\offset, 36, \amp, 0.4])

// map to .kr
k = EntroUnit.new(\sr__k__sine, out:2)
k.sendParams([\min, 20, \max, 80]); // == k.setParams([\mul, 30, \add, 50])
k.sendParams([\lfo, 0.2, \min, 10, \max, 55]);
k.activate

n.mapParam(\offset, k);
n.resetParam(\offset);
n.params

s.sendMsg("/c_getn", 0, 1);
q = OSCFunc({ |msg, time, addr, recvPort|
    msg.postln;
}, '/c_setn');
s.sendMsg("/g_queryTree", 1002); // to fill out synth name
l = OSCFunc({ |msg, time, addr, recvPort|
    msg.postln;
}, '/g_queryTree.reply');


// map to .ar
m = EntroUnit.new(\sr__e__growl, out:0);
m.activate([\amp, 1, \velocity, 0.5, \distance, 0.2]);
n.mapParam(\azimuth, m);

k.deactivate
n.deactivate

k.remove
n.remove
m.remove
q.remove
l.remove

s.queryAllNodes
Entropia.units
Entropia.removeAll
Entropia.rootNode

// TODO:
// before assigning control bus, check if it's output exceeds parameter's minval and maxval,
// and send scaled values instead of assign "cN"


// g = s.nextNodeID;
// x = s.nextNodeID;
// y = s.nextNodeID;
// z = s.nextNodeID;
// u = 4; // route bus
// s.sendMsg("/g_new", g);
// s.sendBundle(0.1,
//     // add synth to new group's head
//     ["/s_new", \sr__e__pulse, x, 0, g, \route, u, \velocity, 0, \att, 0.5],
//     // add inserts to new group's head
//     ["/s_new", \sr__i__delay, y, 3, x, \inbus, u, \route, u],
//     ["/s_new", \sr__i__delayfeed, z, 3, x, \inbus, u, \route, u],
//     // add spatializer to new group's tail
//     ["/s_new", \sr__s__ambisonic2, s.nextNodeID, 1, g, \distance, 0.2, \route, u, \outbus, 0],
// );
//
// s.sendMsg("/n_set", g, \azimuth, -0.5pi);
// s.sendMsg("/n_set", g, \param1, 0.8);
//
// s.sendMsg("/n_set", y, \amp, 0);
// s.sendMsg("/n_set", z, \amp, 0);
//
// s.sendMsg("/n_set", g, \gate, 0, \rel, 0.5);