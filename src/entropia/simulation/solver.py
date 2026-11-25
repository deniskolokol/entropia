import taichi as ti

from .kernels import integrate
from .state import ParticleState


class Simulation:
    def __init__(
        self,
        particle_count: int,
        gravity_x: float = 0.0,
        gravity_y: float = -0.5,
    ) -> None:
        self.state = ParticleState(particle_count)
        self.gravity = ti.Vector([gravity_x, gravity_y])

    def step(self, timestep: float) -> None:
        if timestep <= 0:
            raise ValueError("timestep must be positive")

        integrate(
            self.state.positions,
            self.state.velocities,
            timestep,
            self.gravity,
        )
