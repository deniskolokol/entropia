EntroUnit {
    var <>synthname;
    var <>inbus, <route, <>outbus;
    var <>params, <>env;
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
        params = Entropia.getDefaultParams(type);
        bufnum = 0;
        active = false;
        env = this.setEnv;

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

    prepareInsertMsg { |name, newNode, targetNode, action, index|
        // Insert's route (input) comes from pool.
        // Insert's outbus is the next insert's (or spatial synth's) route.
        ^["/s_new", name,
            newNode, action, targetNode,
            \routeIn, route[index][\bus],
            \routeOut, route[index+1][\bus]
        ]
    }

    addInsert { |name, i|
        // Inserts effect synth to `i` position in group.
        // Updates routing table.
        var msg, newNode = Entropia.nextNode();
        if (this.isActive && route.isNil.not) {
            msg = this.prepareInsertMsg(name, newNode, route[i][\node], 4, i);
            route[i] = merge(route[i], (name: name, node: newNode), { |a, b| b });
            Entropia.sendMessage(msg)
        }
    }

    getInsertMsg {
        // Server message for inserting effect synth into the group.
        // Adds insert messages starting from `route`s tail,
        // ignoring the last element (spatial synth).
        var msg = Array.fill(route.size-1, {nil});
        (route.size-2..0).do { |i|
            msg[i] = this.prepareInsertMsg(route[i][\name],
                newNode: route[i][\node],
                targetNode: node,
                action: 0, index: i);
        };
        ^msg
    }

    getSpatialMsg {
        // Places spatializer to group's tail.
        // In/out for spatial synth is the last element in `route`.
        var msg;
        spatialNode = route.last[\node];
        msg = ["/s_new", spatial,
            spatialNode, 1, node,
            \route, route.last[\bus],
            \outbus, outbus,
            \trigID, trigID
        ]
        ++ [\depth, Entropia.depth, \maxDist, Entropia.maxDist]
        ++ [\speakerAzim, $[] ++ Entropia.speakersAzim ++ [$]]
        ++ [\speakerDist, $[] ++ Entropia.speakersDist ++ [$]]
        ++ [\speakerElev, $[] ++ Entropia.speakersElev ++ [$]];
        ^msg
    }

    getSynthMsg {
        // Places generator to a new group's head.
        var msg;
        synthNode = Entropia.nextNode();
        msg = ["/s_new", synthname,
            synthNode, 0, node,
            \inbus, inbus,
            \route, route.first[\bus],
            \bufnum, bufnum,
        ];
        msg = msg ++ params;
        ^msg
    }

    groupInit {
        var pool = Entropia.nextRoutePool;
        var initBundle;
        route = Array.fill(pool.size, nil);
        // inserts
        Entropia.inserts.do { |name, i|
            route[i] = (
                bus: pool[i],
                node: Entropia.nextNode(),
                name: name
            )
        };
        // spatializer
        route[route.size-1] = (
            bus: pool.last,
            node: Entropia.nextNode(),
            name: spatial
        );
        initBundle = List[
            ["/error", 0], // turn errors off locally
            ["/g_new", node, 0, Entropia.rootNode[type]],
        ];
        initBundle.add(this.getSpatialMsg);
        this.getInsertMsg.do { |msg|
            initBundle.add(msg);
        };
        initBundle.add(this.getSynthMsg);
        Entropia.sendBundle(initBundle.asArray);
    }

    controlInit {
        // Places a stack of controls to the root's group tail.
        Entropia.sendMessage(["/s_new", synthname,
            node, 1, Entropia.rootNode[type],
            \trigID, trigID,
            \inbus, inbus,
            \outbus, outbus,
            \bufnum, bufnum,
        ] ++ params);
    }

    groupRemove { |release|
        ^[
            ["/n_set", node, \rel, release ? 2.rand, \gate, 0],
            ["/n_free", node]
        ]
    }

    activate { |parm| // list of [key, value] pairs
        spatial = ("sr__s__ambisonic" ++ Entropia.speakers.size.asString).asSymbol;
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