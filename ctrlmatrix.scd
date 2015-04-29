(
var win;
var paneMatrix, paneSettings, paneSynths, paneSynth,
    paneArSynths, paneConnections,
    paneKrSynths, paneGrid,
    pane;
var synthType, synthIn, synthOut;
var btPanic, master;
var paneWidth, paneHeight;
var button, buttonCheckbox, knob, slider, dropdown, compView, levelInd, sliderGrid;
var valAsApec;
var colorBtUp=Color.grey(0.6), colorBtDown=Color.red,
    colorBtLabel=Color.grey(0.2), colorPane=Color.grey(0.3),
    colorStringBg = Color.grey(alpha:0.1), colorString=Color(0.8, 0.8, 0.8);
var clean;
var synthsAr=["rock", "blues", "electronica"],
    synthsKr=["sine", "saw", "lfnoise0", "lfnoise1", "lfnoise2"];
var outBus=(0..Server.default.options.numAudioBusChannels-1),
    internalBus=(10..Server.default.options.numAudioBusChannels-1),
    krBus = (0..Server.default.options.numControlBusChannels-1);
var oscResponders=["l_hand", "r_hand", "drone"];


// interface
win = Window("ctrl matrix", Window.screenBounds.width@Window.screenBounds.height);

// helper functions
valAsApec = { |spec|
    [
        spec.atFail(\minval, {0}),
        spec.atFail(\maxval, {1}),
        spec.atFail(\warp, {\lin}),
        spec.atFail(\step, {0}),
        spec.atFail(\default, {0})
    ].asSpec
};
paneWidth = { |par, scale=1| (par.bounds.width * scale - 6).floor };
paneHeight = { |par, scale=1| (par.bounds.height * scale - 6).floor };
button = { |par, label, action, scaleH=1, scaleW=1|
    Button(par, paneWidth.(par, scaleW)@paneHeight.(par, scaleH)).states_([
        [label, colorBtLabel, colorBtUp]
    ])
    .font_(Font("Helvetica", 12))
    .action_({ |bt| action.(bt.value) })
    .canFocus_(false);
};
buttonCheckbox = { |par, label, action, value, scaleH=1, scaleW=1|
    Button(par, paneWidth.(par, scaleW)@paneHeight.(par, scaleH)).states_([
        [label, colorBtLabel, colorBtUp],
        [label, colorString, colorBtDown]
    ])
    .value_(value)
    .action_({ |bt| action.(bt.value) })
    .font_(Font("Helvetica", 12))
    .canFocus_(false);
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
    ).font_(Font("Helvetica", 12));
};
slider = { |par, label, spec, action, default=0, layout='horz', scale=1|
    var labelWidth=0, numberWidth=45;
    var bounds=paneWidth.(par)@20;
    if (label.isNil.not) { labelWidth = label.size * 5 };
    if (layout == 'horz') {
        bounds = (paneWidth.(par, scale))@20;
        numberWidth = 30;
    } {
        bounds = 30@(paneHeight.(par, scale))
    };
    EZSlider(par, bounds, label, spec, { |ez| action.(ez.value) }, default,
        labelWidth: labelWidth, numberWidth: numberWidth, layout: layout)
    .font_(Font("Helvetica", 12))
    .setColors(stringColor: Color.white)
};
dropdown = { |par, label, items, scale=1|
    var labelWidth=0;
    if (label.isNil.not) { labelWidth = label.size * 9};
    EZPopUpMenu(par, paneWidth.(par, scale)@20, label, items, labelWidth:labelWidth)
        .font_(Font("Helvetica", 11))
        .setColors(colorStringBg, colorString)
};
compView = { |par, color, scaleW=1, scaleH=1|
    var vw;
    if (color.isNil) { color = colorPane };
    vw = CompositeView(par,
        paneWidth.(par, scaleW)@paneHeight.(par, scaleH)
    ).background_(color);
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

paneSettings = compView.(paneMatrix, scaleW: 0.2, scaleH: 0.4);
master = slider.(paneSettings, "Master", \db.asSpec,
    { |sl| s.volume.volume = sl.value }, 1);
btPanic = button.(paneSettings, "PANIC", { |val| val.postln}, 0.2, 0.25);

paneArSynths = compView.(paneMatrix, scaleW: 0.8, scaleH: 0.4);
paneConnections = compView.(paneArSynths, scaleH: 0.15, color: Color.grey(0.7));
// .ar synth panel and controls
paneSynths = compView.(paneArSynths, scaleH: 0.85);
8.do { |i|
    var paneKnobs, paneSlid;
    paneSynth = compView.(paneSynths, scaleW: 0.125);
    // synth
    pane = compView.(paneSynth, scaleW: 0.9);
    synthType = dropdown.(pane, items:synthsAr);
    synthIn = dropdown.(pane, "I", items:internalBus, scale: 0.5);
    synthOut = dropdown.(pane, "O", items:outBus, scale: 0.5);
    buttonCheckbox.(pane, "ON", { |val| val.postln }, scaleW: 0.5, scaleH: 0.1);
    button.(pane, "RESET", { |val| val.postln }, scaleW: 0.5, scaleH: 0.1);
    paneKnobs = compView.(pane, scaleW: 0.6, scaleH: 0.7);
    [\none, \none, \none].do { |key| // Dummies
        // XXX dynamic labels deending on the synth type
        knob.(paneKnobs, action: { |k| k.postln }, scaleH: 0.33);
    };
    paneSlid = compView.(pane, scaleW: 0.4, scaleH: 0.7);
    slider.(paneSlid, "mul", \unipolar.asSpec,
        { |sl| sl.postln }, 0, \vert, scaleH: 0.5, scaleW: 0.8);
    // level meter
    pane = compView.(paneSynth, scaleW: 0.11);
    levelInd.(pane, 0.5);

};

paneKrSynths = compView.(paneMatrix, scaleW: 0.2, scaleH: 0.6);
// .kr synth panel and controls
8.do { |i|
    paneSynth = compView.(paneKrSynths, scaleH: 0.125);
    pane = compView.(paneSynth, scaleW: 0.95);
    synthType = dropdown.(pane, items:synthsKr, scale: 0.25);
    synthIn = dropdown.(pane, "in", items:oscResponders, scale: 0.3);
    slider.(pane, "", \unipolar.asSpec,
        { |sl| sl.postln }, 0, scale: 0.45);
    [\none, \none, \none].do { |key| // Dummies
        // XXX dynamic labels depending on the synth type
        knob.(pane, action: { |k| k.postln }, layout: \line2, scaleW: 0.3, scaleH: 0.5);
    };
    [\ON, \OFF].do { |label|
        buttonCheckbox.(pane, label, { |val| val.postln }, scaleW:0.12, scaleH:0.5);
    };
    levelInd.(paneSynth, 0.5, scaleW:0.05);
};

paneGrid = compView.(paneMatrix, scaleW: 0.8, scaleH: 0.6);
sliderGrid = MultiSliderView(paneGrid, (paneGrid.bounds.width-10)@(paneGrid.bounds.height-10))
    .valueThumbSize_(50)
    .indexThumbSize_(30)
    .colors_(colorBtUp, colorBtDown)
    .step_(1 / 8)
    .value_(Array.fill(8 * 4, { 1 })) // size is set automatically when you set the value
    .action_({ |msv| msv.value.postln };
);

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
};

//win.fullScreen.front;
win.front;

// clean everything on exit
clean = {
    win.close;
};

CmdPeriod.doOnce({
    clean.();
});
)