from typing import Any

from pythonosc.udp_client import SimpleUDPClient


class OSCSender:
    def __init__(self, host: str, port: int) -> None:
        self._client = SimpleUDPClient(host, port)

    def send_message(self, address: str, value: Any) -> None:
        self._client.send_message(address, value)
