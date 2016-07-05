// Environment module.
//
// Bus numbers
//     external output:
//         0..(numOutputBusChannels-1)
//
//     in-out routing for granular synths:
//         numOutputBusChannels .. (numOutputBusChannels + arUnitsNum)
//
//     available for internal routings in groups (routePool):
//         (numOutputBusChannels + arUnitsNum) .. numAudioBusChannels-1

Entropia {
    var thisVersion = "0.0.0";
    var thisState = \pre_alpha;

    classvar <arUnitsNum=4; // default number of .ar synths
    classvar <insertsNum=4; // default number of inserts in each group
    classvar <specs, <params; // params
    classvar <depth, <inbus, <outbus, <routePool; // audio conf
    classvar <startTrigID;
    classvar <buffer;
    classvar <rootNode;
    classvar <speakers, <maxDist; // speakers setup
    classvar <inserts; // inserts setup
    classvar <>units;
    classvar <srv;

	*initClass {
        // server related
        Class.initClassTree(Server);
        StartUp.add {
            Server.default = Server.internal;
            srv = Server.default;
            srv.options.numInputBusChannels = 4;
            srv.options.numOutputBusChannels = 10;
            srv.options.numAudioBusChannels = max(
                128, // minimum num of buses
                // or
                arUnitsNum // max number of units
                    * ( // multiplied by
                        insertsNum // number of inserts
                        + 1 // plus one bus for routing to spatializer
                    )
                + srv.options.numInputBusChannels // plus input buses
                + srv.options.numOutputBusChannels // plus output buses
            );

            srv.options.memSize = 262144;
            srv.options.blockSize = 512;

            srv.boot;
            srv.waitForBoot{
                srv.meter;
                // root IDs for synths
                rootNode = (ar: srv.nextNodeID, kr: srv.nextNodeID);
                srv.sendMsg("/g_new", rootNode[\ar], 0, 1);
                srv.sendMsg("/g_new", rootNode[\kr], 0, 1);

                routePool = [
                    srv.options.numOutputBusChannels + arUnitsNum,
                    srv.options.numAudioBusChannels - 1
                ];

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

        // speakers setup (distance, azimuth and elevation)
        speakers = List[
            (dist: 1, azim: -0.25pi, elev: 0pi),
            (dist: 1, azim: -0.75pi, elev: 0pi),
        ];
        maxDist = 1; // distance to the farthest speaker

        // default inserts setup
        inserts = Array.fill(insertsNum, {\sr__i__pass});
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

    *setInsert { |name, index|
        // adds a new insert to all units
        units.do { |u| u.addInsert(name, index) };
    }

    *resetInsert { |index|
        // reset insert to units (changes it to 'pass')
        ^setInsert(\sr__i__pass, index)
    }

    *clipInc { |in=0, step=1, lo=0, hi=inf|
        // increments `in` until `in + step` reaches `hi`, then resets to `lo`.
        ^(((in ? 0) + step).clip(lo, hi) % hi).clip(lo, hi)
    }

    *minMax2mulAdd { |min, max|
        // calculates \mul and \add based on \min and \max
        var mul, add;
        mul = max.absdif(min) * 0.5;
        add = min + mul;
        ^[mul, add]
    }

    *mulAdd2minMax { |mul, add|
        // calculates \mul and \add based on \min and \max
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

    *nextRoutePool {
        var lo, hi, next, current= -1;
        current = (
            all {: u.route[u.route.size-1][\bus], u <- units,
                u.isActive, u.type == \ar} ? []
        ).sort.last;
        #lo, hi = routePool;
        next = Entropia.clipInc(current, 1, lo, hi);
        ^(next..(next+insertsNum));
    }

    *nextTrigID {
        var current=(all {: u.trigID, u <- units, u.isActive} ? []).sort.last;
        ^Entropia.clipInc(current, 1, startTrigID);
    }

    *nextNode {
        ^srv.nextNodeID
    }

    *sendBundle { |msg, time=0.1|
        msg.do { |m| m.postln };
        srv.listSendBundle(time, msg);
    }

    *sendMessage { |msg|
        srv.listSendMsg(msg);
    }
}