from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    window_width: int = 800
    window_height: int = 600
    particle_count: int = 512
    timestep: float = 1.0 / 60.0
    gravity_x: float = 0.0
    gravity_y: float = -0.5
    osc_listen_host: str = "127.0.0.1"
    osc_listen_port: int = 9000
    osc_send_host: str = "127.0.0.1"
    osc_send_port: int = 9001
