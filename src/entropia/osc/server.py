import logging
import threading

from pythonosc.dispatcher import Dispatcher
from pythonosc.osc_server import ThreadingOSCUDPServer

logger = logging.getLogger(__name__)


class OSCServer:
    def __init__(
        self,
        host: str,
        port: int,
        dispatcher: Dispatcher,
    ) -> None:
        self._server = ThreadingOSCUDPServer((host, port), dispatcher)
        self._thread = threading.Thread(
            target=self._server.serve_forever,
            name="osc-server",
            daemon=True,
        )

    def start(self) -> None:
        self._thread.start()
        logger.info("OSC server listening on %s:%d", *self._server.server_address)

    def close(self) -> None:
        if self._thread.is_alive():
            self._server.shutdown()
            self._thread.join()
        self._server.server_close()
