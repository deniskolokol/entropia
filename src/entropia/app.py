import logging
import math

import taichi as ti

from .config import Settings
from .logging_config import configure_logging
from .osc import OSCReceiver, OSCSender
from .rendering import Renderer
from .simulation import Simulation

logger = logging.getLogger(__name__)


def main() -> None:
    configure_logging()
    settings = Settings()
    ti.init(arch=ti.cpu)

    simulation = Simulation(
        settings.particle_count,
        settings.gravity_x,
        settings.gravity_y,
    )
    renderer = Renderer(settings.window_width, settings.window_height)
    receiver = OSCReceiver(settings.osc_listen_host, settings.osc_listen_port)
    sender = OSCSender(settings.osc_send_host, settings.osc_send_port)

    receiver.start()
    sender.send_message("/particles/count", settings.particle_count)
    logger.info("Simulation started with %d particles", settings.particle_count)

    try:
        while renderer.running:
            for address, args in receiver.drain_messages():
                if address == "/gravity" and len(args) == 2:
                    if all(
                        isinstance(value, (int, float))
                        and math.isfinite(float(value))
                        for value in args
                    ):
                        simulation.gravity = ti.Vector(
                            [float(args[0]), float(args[1])]
                        )
                    else:
                        logger.warning("Ignoring non-numeric /gravity message")

            simulation.step(settings.timestep)
            renderer.render(simulation.state.positions.to_numpy())
    finally:
        receiver.close()
