EntroUnit {
    var <>synthname;
    var <>inbus, <route, <>outbus;
    var <>params, <>env, <>insert;
    var <>active;
    var <>bufnum;

    var <spatial;
    var <node, <synthNode, <spatialNode;
    var <trigID;
    var <type; // \ar or \kr

    *initClass {
        Class.initClassTree(Entropia);
    }

	*new { |synth, in, out|
        ^super.new.initEntroUnit(synth, in, out);
	}

    initEntroUnit { |synth, in, out|
        inbus = in ? Entropia.inbus;
        outbus = out ? Entropia.outbus;
        synthname = synth;
        if ("sr__(e|g|p){1}__[a-zA-Z0-9]+".matchRegexp(synthname.asString)) {
            type = \ar
        };
        if (synthname.asString.beginsWith("sr__k__")) {
            type = \kr
        };
        if (type.isNil) {
            Error("Cannot establish synth type based on its name: %.".format(synthname)).throw;
        };
        spatial = "sr__s__ambisonic" ++ Entropia.speakers.size.asString;
        params = Entropia.getDefaultParams(type);
        bufnum = 0;
        active = false;
        env = this.setEnv;
        insert = #[\reverb, \delay, \conv, \dist];

		Entropia.add(this); // add unit to conf
    }

    isActive {
        ^active
    }

    synthnameShort {
        ^Entropia.synthnameShort(synthname)
    }

    setEnv { |attackTime=0.01, decayTime=0.3, sustainLevel=0.5, releaseTime=1, peakLevel=1, curve= -4, bias=0|
        ^Env.adsr(attackTime, decayTime, sustainLevel, releaseTime, peakLevel, curve, bias);
    }

    randomizeEnv {
        env = this.setEnv(
            0.2.rand, 0.5.rand, 0.5.rand, rrand(0.7, 1), rrand(0.8, 1), 4.rand2, 0.05.rand
        )
    }

    updateParams { |trg|
        var src, min, max, mul, add;

        src = Dictionary.newFrom(params);
        trg = Dictionary.newFrom(trg);

        // \min & \max params affect \mul & \add
        if ([\min, \max].isSubsetOf(trg.keys)) {
            #mul, add = Entropia.minMax2mulAdd(trg[\min], trg[\max]);
            trg = merge(trg, (mul: mul, add: add), { |a, b| b });
        };
        // either way around: \mul & \add affect \min & \max
        if ([\mul, \add].isSubsetOf(trg.keys)) {
            #min, max = Entropia.mulAdd2minMax(trg[\mul], trg[\add]);
            trg = merge(trg, (min: min, max: max), { |a, b| b });
        };
        ^merge(src, trg, { |a, b| b });
    }

    setParams { |parm| // list of [key, value] pairs
        var pStruct, pCurrent, src, trg;

        if (parm.size == 0) {^nil};

        // save the order of current params
        pCurrent = params.reject {|i| params.indexOf(i).odd};

        // update current params with `parm`
        pStruct = this.updateParams(parm);

        // re-apply params saving the order
        params = List.new;
        pCurrent.do { |key| params.add(key).add(pStruct[key])};

        // append new params
        pStruct.keys.do { |key|
            if (pCurrent.includes(key).not) {
                params.add(key).add(pStruct[key])
            }
        };

        // convert back to Array
        params = params.asArray;
    }

    sendParams { |parms|
        this.setParams(parms);
        if (this.active) {
            Entropia.sendMessage(["/n_set", this.node] ++ params);
        }
    }

    mapParam { |name, unit| // unit is EntroUnit instance
        this.setParams([name, ("c" ++ unit.outbus.asString).asSymbol]);
        if (unit.active.not) {
            ^nil
        };
        if (unit.type == \ar) {
            Entropia.sendMessage(["/n_mapa", this.node, name, unit.outbus]);
        } {
            Entropia.sendMessage(["/n_map", this.node, name, unit.outbus]);
        }
    }

    resetParam { |name|
        // remove n_map, leave current value or spec's defaut
        var currMapping, krUnit, func, tsk, val, i, u;
        currMapping = Dictionary.newFrom(params)[name].asString;
        if (currMapping.beginsWith("c").not) {
            ^nil
        };
        // find \kr unit with current mapping
        i = 0;
        while (
            { krUnit.isNil || (i < Entropia.units.size) },
            {
                u = Entropia.units[i];
                if ((u.type == \kr) && ("c" ++ u.outbus.asString == currMapping)) {
                    krUnit = u
                };
                i = i + 1;
            }
        );
        // obtain current value and send it as a fixed param value
        if (krUnit.isNil.not) {
            func = OSCFunc({ |msg| val = msg[2] }, "/c_set");
            Entropia.sendMessage(["/c_get", krUnit.outbus]);
            tsk = Task({
                inf.do { |j|
                    if ((val.isNil.not) || (j >= 10)) { // wait 1s
                        this.sendParams([name, val ? Entropia.specs[name].default]);
                        func.free;
                        tsk.stop;
                    };
                    0.1.wait;
                };
            }).start;
        } {
            this.sendParams([name, Entropia.specs[name].default]);
        };
    }

    prepareInsertMsg {
        // server message for inserting effect synth into the group
        ^nil
    }

    prepareSpatialMsg {
        var msg;
        spatialNode = Entropia.nextNode();
        msg = ["/s_new", spatial,
            spatialNode, 1, node, // spatializer goes to group's tail
            \route, route, \outbus, outbus
        ]
        ++ [\depth, Entropia.depth, \maxDist, Entropia.maxDist]
        ++ [\speakerAzim, $[] ++ Entropia.speakersAzim ++ [$]]
        ++ [\speakerDist, $[] ++ Entropia.speakersDist ++ [$]]
        ++ [\speakerElev, $[] ++ Entropia.speakersElev ++ [$]];
        ^msg
    }

    prepareSynthMsg {
        var msg;
        synthNode = Entropia.nextNode();
        msg = ["/s_new", synthname,
            synthNode, 0, node, // generator goes to a new group's head
            \trigID, trigID,
            \inbus, inbus,
            \route, route,
            \bufnum, bufnum,
        ];
        msg = msg ++ params;
        ^msg
    }

    groupInit {
        route = Entropia.nextRouteBus;
        Entropia.sendBundle([
            ["/error", 0], // turn errors off locally
            ["/g_new", node, 0, Entropia.rootNode[type]],
            this.prepareSpatialMsg(),
            this.prepareSynthMsg()
        ]);
    }

    controlInit {
        Entropia.sendMessage(["/s_new", synthname,
            node, 1, Entropia.rootNode[type], // stack controls to the root's group tail
            \trigID, trigID,
            \inbus, inbus,
            \outbus, outbus,
            \bufnum, bufnum,
        ] ++ params).postln;
    }

    groupRemove { |release|
        ^[
            ["/n_set", node, \rel, release ? 2.rand, \gate, 0],
            ["/n_free", node]
        ]
    }

    activate { |parm| // list of [key, value] pairs
        this.setParams(parm);
        if (this.active) {
            ^node
        };
        node = Entropia.nextNode;
        trigID = Entropia.nextTrigID;
        if (type == \ar) {
            this.groupInit
        } {
            this.controlInit
        };
        // TODO - wait for the answer from server and set `active` accordingly
        active = true;
        ^node // return ID of the Group created
    }

    getMapped {
        // returns the list of units and their params
        // mapped to the output of current unit
        var unitParams, mappedUnits;
        mappedUnits = Dictionary.new;
        Entropia.units.do { |unit|
            if (unit != this) {
                unitParams = Dictionary.newFrom(unit.params);
                unitParams.keys.do { |name|
                    if (unitParams[name].asString == ("c" ++ outbus.asString)) {
                        if (mappedUnits.keys.includes(unit)) {
                            mappedUnits[unit].add(name)
                        } {
                            mappedUnits.put(unit, List[name])
                        }
                    }
                }
            }
        };
        ^mappedUnits
    }

    doDeactivate { |release=0.1|
        Routine({
            this.groupRemove(release).do { |msg|
                Entropia.sendMessage(msg);
                release.wait;
            };
            node = nil;
            route = nil;
            trigID = nil;
            active = false;
        }).play;
    }

    deactivate { |release=0.1|
        var mapped, val, func, tsk;
        if (active.not) {
            ^nil
        };
        // get the list L of (unit: [params]) mapped to the output of current one
        mapped = this.getMapped;
        if (mapped.size > 0) {
            // get the curr value on this.outbus (see resetParam)
            func = OSCFunc({ |msg| val = msg[2] }, "/c_set");
            Entropia.sendMessage(["/c_get", outbus]);
            tsk = Task({
                inf.do { |j|
                    if ((val.isNil.not) || (j >= 10)) { // wait 1s
                        // send value to all params of mapped units or reset to default
                        mapped.keysValuesDo { |unit, names|
                            names.do { |name|
                                unit.sendParams([name, val ? Entropia.specs[name].default]);
                            };
                        };
                        // actually deactivate current unit
                        this.doDeactivate(release);
                        func.free;
                        tsk.stop;
                    };
                    0.1.wait;
                };
            }).start;
        } {
            // no unites mapped to the current one
            this.doDeactivate(release);
        };
    }

    remove {
        this.deactivate;
        Entropia.remove(this)
    }
}