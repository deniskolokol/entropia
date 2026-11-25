import taichi as ti


class Renderer:
    def __init__(self, width: int, height: int, title: str = "Entropia") -> None:
        self._gui = ti.GUI(
            title,
            res=(width, height),
            background_color=0x101018,
        )

    @property
    def running(self) -> bool:
        return self._gui.running

    def render(self, positions) -> None:
        self._gui.circles(positions, radius=4, color=0x66CCFF)
        self._gui.show()
