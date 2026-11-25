import taichi as ti

from .kernels import initialize_particles


class ParticleState:
    def __init__(self, particle_count: int) -> None:
        if particle_count <= 0:
            raise ValueError("particle_count must be positive")

        self.positions = ti.Vector.field(2, dtype=ti.f32, shape=particle_count)
        self.velocities = ti.Vector.field(2, dtype=ti.f32, shape=particle_count)
        initialize_particles(self.positions, self.velocities)
