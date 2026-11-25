import pytest
import taichi as ti

from entropia.simulation import Simulation


@pytest.fixture(scope="module", autouse=True)
def initialize_taichi() -> None:
    ti.init(arch=ti.cpu)


def test_step_applies_gravity_and_bounces_at_bounds() -> None:
    simulation = Simulation(particle_count=1)

    simulation.step(0.1)
    assert simulation.state.positions[0][1] == pytest.approx(0.195, abs=1e-5)

    simulation.state.positions[0] = [0.5, 0.001]
    simulation.state.velocities[0] = [0.0, -1.0]
    simulation.step(0.1)

    assert simulation.state.positions[0][1] == pytest.approx(0.0, abs=1e-5)
    assert simulation.state.velocities[0][1] > 0.0


def test_step_rejects_non_positive_timestep() -> None:
    simulation = Simulation(particle_count=1)
    with pytest.raises(ValueError, match="timestep must be positive"):
        simulation.step(0.0)
