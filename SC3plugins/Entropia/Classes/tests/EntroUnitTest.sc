EntroUnitTest : UnitTest {
    // run like this:
    // EntroUnitTest.reset;
    // EntroUnitTest.new.run;
    // ... or
    // EntroUnitTest.new.runTestMethod(EntroUnitTest.findMethod(\test_new));

    var s, <defaultArParams;

    setUp {
        defaultArParams = [
            \offset, 60, \cutoff, 440, \rq, 0.707, \amp, 0,
            \azimuth, 0, \distance, 0, \elevation, 0, \velocity, 0
        ];
        s = Server.internal;
        Entropia.removeAll;
    }

    tearDown {

    }

    test_new {
        var unit = EntroUnit.new(\sr__e__pulse);
        this.assert(unit.synthname == \sr__e__pulse, "Unit synth name test.");
        this.assert(unit.synthnameShort == "pulse", "Unit short name test.");
        this.assert(unit.active == false, "Unit active test.");
        this.assert(unit.type == \ar, "Unit type test.");
        this.assert(unit.inbus == Entropia.inbus, "Inbus test.");
        this.assert(unit.route == nil, "Inactive unit does not have route bus assigned.");
        this.assert(unit.node == nil, "Inactive unit does not have node assigned.");
        this.assert(unit.outbus == Entropia.outbus, "Outbus test.");
        this.assert(unit.spatial == ("sr__s__ambisonic" ++ Entropia.speakers.size.asString),
            "Spatial synth is defined by the number of speakers.");
        this.assert(unit.params == this.defaultArParams, "Test default params.");
        this.assert(Entropia.units.size == 1, "Entropia units test.");
        this.assert(Entropia.units[0] == unit, "Entropia unit test.");
    }

    test_activate {
        var unit = EntroUnit.new(\sr__e__pulse);
        1.wait;
        unit.activate;
        this.assert(unit.active == true, "Active unit test.");
        this.assert(unit.route == Entropia.routePool[0], "Active unit route test.");
        this.assert(unit.node.class == Integer, "Active unit sits at a node.");
        unit.activate([\amp, 1, \velocity, 0.5, \distance, 0.2]); // second activation re-sets params
        this.assert(unit.params != this.defaultArParams, "Test re-written params.");
    }

    test_deactivate {
        var unit;
        unit = EntroUnit.new(\sr__e__pulse);
        unit.activate;
        unit.deactivate;
		1.0.wait; // we are inside a Routine
        this.assert(unit.active == false, "Test inactive unit.");
        this.assert(unit.node == nil, "Inactive unit does not have node assigned.");
        this.assert(unit.route == nil, "Inactive unit does not have route bus assigned.");
        this.assert(Entropia.units[0] == unit, "Test unit is present");
    }

    test_remove {
        var unit;
        unit = EntroUnit.new(\sr__e__pulse);
        unit.activate;
        unit.remove;
		1.0.wait; // we are inside a Routine
        this.assert(Entropia.units.includes(unit) == false, "Test unit is deleted from Entropia.units.");
    }

    test_setParams {
        var unitAr, unitKr, parmTest;
        unitAr = EntroUnit.new(\sr__e__pulse);
        unitAr.setParams([\cutoff, 220, \amp, 0.8]);
        this.assert(unitAr.params == [
            \offset, 60, \cutoff, 220, \rq, 0.707, \amp, 0.8,
            \azimuth, 0, \distance, 0, \elevation, 0, \velocity, 0
        ], "Update params with preserving order.");
        unitAr.setParams([\az, 0.1pi]);
        this.assert(unitAr.params == [
            \offset, 60, \cutoff, 220, \rq, 0.707, \amp, 0.8,
            \azimuth, 0, \distance, 0, \elevation, 0, \velocity, 0,
            \az, 0.1pi
        ], "Synth specific params are added to the end of list.");

        unitKr = EntroUnit.new(\sr__k__sine);
        unitKr.setParams([\min, 20, \max, 80]);
        parmTest = unitKr.params;
        unitKr.setParams([\mul, 30, \add, 50]);
        this.assert(unitKr.params == parmTest, "Update params with \min, \max affects \mul, \add and vice versa.");

        unitKr.setParams([\mul, 75, \add, 25]);
        parmTest = Dictionary.newFrom(unitKr.params);
        unitKr.setParams([\mul, -75, \add, 25]);
        this.assert(Dictionary.newFrom(unitKr.params)[\min] == parmTest[\min],
            "Negative \mul doesn't affect \min, \max.");
        this.assert(Dictionary.newFrom(unitKr.params)[\max] == parmTest[\max],
            "Negative \mul doesn't affect \min, \max.");
    }

    test_mapParam {
        var unitAr, unitKr;
        unitAr = EntroUnit.new(\sr__e__pulse);
        unitKr = EntroUnit.new(\sr__k__sine, out:2);
        unitKr.activate;
        unitAr.activate;
        unitAr.mapParam(\offset, unitKr);
        this.assert(unitAr.params == [
            \offset, \c2, \cutoff, 440, \rq, 0.707, \amp, 0,
            \azimuth, 0, \distance, 0, \elevation, 0, \velocity, 0
        ], "Map param to kr bus.");
        this.assert(unitAr.trigID - unitKr.trigID == 1, "Successive trigIDs in the order of activation");
    }

    //XXX: Fails if EntroUnitTest.new.run
    //XXX: Deactivating .kr also deactivates .ar!
    test_resetParam {
        var unitAr, unitKr, valTest, name=\offset, minVal=20, maxVal=80;
        unitAr = EntroUnit.new(\sr__e__pulse);
        unitAr.activate;
        unitKr = EntroUnit.new(\sr__k__sine, out:2);
        unitKr.activate([\min, minVal, \max, maxVal]);
        0.5.wait;
        unitAr.mapParam(name, unitKr);
        0.5.wait;
        unitAr.resetParam(name);
        1.5.wait;
        Entropia.units.do { |u| [u.node, u.type, u.active].postln };
        s.queryAllNodes;
        valTest = Dictionary.newFrom(unitAr.params)[name];
        this.assert(Dictionary.newFrom(unitAr.params)[name] != Entropia.specs[name].default,
            format("Params holds a current value after reset. % vs. %",
                valTest,
                Entropia.specs[name].default
            )
        );
        this.assert(
            ((valTest >= minVal) && (valTest <= maxVal)),
            "Current value after reset is in the defined scope."
        );
    }
}