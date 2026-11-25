import taichi as ti


@ti.kernel
def initialize_particles(
    positions: ti.template(),
    velocities: ti.template(),
):
    for i in range(positions.shape[0]):
        column = i % 32
        row = i // 32
        positions[i] = ti.Vector(
            [
                (ti.cast(column, ti.f32) + 0.5) / 32.0,
                ti.min(0.2 + ti.cast(row, ti.f32) * 0.03, 0.9),
            ]
        )
        velocities[i] = ti.Vector([0.0, 0.0])


@ti.kernel
def integrate(
    positions: ti.template(),
    velocities: ti.template(),
    timestep: ti.f32,
    gravity: ti.types.vector(2, ti.f32),
):
    for i in range(positions.shape[0]):
        velocities[i] += gravity * timestep
        positions[i] += velocities[i] * timestep

        for axis in ti.static(range(2)):
            if positions[i][axis] < 0.0:
                positions[i][axis] = 0.0
                velocities[i][axis] = ti.abs(velocities[i][axis]) * 0.8
            elif positions[i][axis] > 1.0:
                positions[i][axis] = 1.0
                velocities[i][axis] = -ti.abs(velocities[i][axis]) * 0.8
