Entropia {
    var thisVersion = "0.0.0";
    var thisState = \pre_alpha;

    classvar <specs, <params; // params
    classvar <depth, <inbus, <outbus, <routePool, <route; // audio conf
    classvar <startTrigID;
    classvar <buffer;
    classvar <rootNode;
    classvar <speakers, <maxDist; // speakers setup
    classvar <>units;
    classvar <srv;

	*initClass {
        Class.initClassTree(Server);
        StartUp.add { // TODO! Move it to the class that contains EntroUnits, when done
            Server.default = Server.internal;
            srv = Server.default;
            srv.options.numInputBusChannels = 4;
            srv.options.numOutputBusChannels = 10;
            srv.options.memSize = 262144;
            srv.options.blockSize = 512;

            srv.boot;
            srv.waitForBoot{
                srv.meter;
                // root IDs for synths
                rootNode = (ar: srv.nextNodeID, kr: srv.nextNodeID);
                srv.sendMsg("/g_new", rootNode[\ar], 0, 1);
                srv.sendMsg("/g_new", rootNode[\kr], 0, 1);

                // load synth defs
                Class.initClassTree(EntroSynthDefs);
            };
        };

        // params ControlSpec
		Class.initClassTree(Spec);
		specs = Dictionary[
            \azimuth -> ControlSpec(-1pi, 1pi, \lin, 0.01, 0),
            \distance -> ControlSpec(0, 2.sqrt, \lin, 0.01, 0),
            \elevation -> ControlSpec(-0.5pi, 0.5pi, \lin, 0.01, 0),
            \velocity -> \unipolar.asSpec,
            \depth -> ControlSpec(1, 10, \lin, 0.1, 5),
            \offset -> \midinote.asSpec,
            \cutoff -> \freq.asSpec,
            \rq -> \rq.asSpec,
            \lfo -> ControlSpec(0.01, 100, \lin, 0.01, 0.5, units: " Hz"), // dummy, 0.01..1.000 | 1..100
            \min -> ControlSpec(-1, 0.99, \lin, 0.01, -1),
            \max -> ControlSpec(-0.99,  1, \lin, 0.01, 1),
            \amp -> \amp.asSpec,
            \mul -> \amp.asSpec, // dummy, controllable by GUI
            \add -> \amp.asSpec // dummy, controllable by GUI
        ];

        // default synth params
        params = Dictionary[
            \ar -> #[
                \offset, \cutoff, \rq, \amp, // default controllable params
                \azimuth, \distance, \elevation, \velocity // default modulatable params
            ],
            \kr -> #[\lfo, \min, \max, \depth]
        ];

        depth = 3.5; // default audio field depth (1..10)
        inbus = 12; // default input channel
        outbus = 0; // default output channel
        buffer = 0; // default buffer
        startTrigID = 60;

        // Bus numbers available for internal routings in groups.
        routePool = [20, 51];

        // speakers setup (distance, azimuth and elevation)
        speakers = List[
            (dist: 1, azim: -0.25pi, elev: 0pi),
            (dist: 1, azim: -0.75pi, elev: 0pi),
        ];
        maxDist = 1; // distance to the farthest speaker
    }

    *synthnameShort { |sn|
        // Short synth name starts from 7th symbol (after "\sr__?__").
        var name = sn.asString;
        if ("sr__(e|g|p|k|r|s){1}__[a-zA-Z0-9]+".matchRegexp(name)) {
            ^name[7..]
        };
        ^name
    }

    *getDefaultParams { |synthType|
        ^all {: [p, specs[p].default], p <- params[synthType]}.flatten
    }

	*add { |entroUnit|
        units = units.add(entroUnit);
    }

	*remove { |entroUnit|
        entroUnit.deactivate;
        units.remove(entroUnit);
    }

	*removeAll {
        units.do { |u| u.deactivate };
        units = [];
    }

    *speakersAzim {
        ^all{: sp.azim, sp <- speakers}
    }

    *speakersDist {
        ^all{: sp.dist, sp <- speakers}
    }

    *speakersElev {
        ^all{: sp.elev, sp <- speakers}
    }

    *removeSpeaker { |index|
        if ((speakers.size-1) < 2) {
            postf("WARNING! Cannot remove speaker %! At least two speakers should be defined!", index+1);
        } {
            speakers.pop(index);
        }
    }

    // increments `in` until `in + step` reaches `hi`, then resets to `lo`.
    *clipInc { |in=0, step=1, lo=0, hi=inf|
        ^(((in ? 0) + step).clip(lo, hi) % hi).clip(lo, hi)
    }

    // calculates \mul and \add based on \min and \max
    *minMax2mulAdd { |min, max|
        var mul, add;
        mul = max.absdif(min) * 0.5;
        add = min + mul;
        ^[mul, add]
    }

    // calculates \mul and \add based on \min and \max
    *mulAdd2minMax { |mul, add|
        var min, max;
        min = mul.abs.neg + add;
        max = min + (mul.abs * 2);
        ^[min, max]
    }

    *nextRouteBus {
        var current, lo, hi;
        current = (all {: u.route, u <- units, u.isActive} ? []).sort.last;
        #lo, hi = routePool;
        ^Entropia.clipInc(current, 1, lo, hi);
    }

    *nextTrigID {
        var current=(all {: u.trigID, u <- units, u.isActive} ? []).sort.last;
        ^Entropia.clipInc(current, 1, startTrigID);
    }

    *nextNode {
        ^srv.nextNodeID
    }

    *sendBundle { |msg, time=0.1|
        srv.listSendBundle(time, msg);
    }

    *sendMessage { |msg|
        srv.listSendMsg(msg);
    }
}