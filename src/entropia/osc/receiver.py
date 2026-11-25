import logging
import queue
from typing import Any

from pythonosc.dispatcher import Dispatcher

from .server import OSCServer

logger = logging.getLogger(__name__)


class OSCReceiver:
    def __init__(self, host: str, port: int) -> None:
        self._messages: queue.SimpleQueue[tuple[str, tuple[Any, ...]]] = (
            queue.SimpleQueue()
        )
        dispatcher = Dispatcher()
        dispatcher.set_default_handler(self._enqueue_message)
        self._server = OSCServer(host, port, dispatcher)

    def _enqueue_message(self, address: str, *args: Any) -> None:
        self._messages.put((address, args))

    def start(self) -> None:
        self._server.start()

    def drain_messages(self) -> list[tuple[str, tuple[Any, ...]]]:
        messages = []
        while True:
            try:
                messages.append(self._messages.get_nowait())
            except queue.Empty:
                return messages

    def close(self) -> None:
        self._server.close()
        logger.info("OSC receiver stopped")
