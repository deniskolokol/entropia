EntropiaTest : UnitTest {
    setUp {
        Entropia.removeAll;
    }

    test_defaults {
        this.assert(Entropia.srv.options.numAudioBusChannels == 128, "Number of audio bus channels");
        this.assert(Entropia.routePool == [14, 127], "Route pool (bus numbers available for internal routings in groups)");
        this.assert(Entropia.nextRoutePool == [ 14, 15, 16, 17, 18 ], "Initial route pool.")
    }
}