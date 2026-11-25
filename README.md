# entropia

Taichi-based physics engine for particle/object simulation in calibrated space,
with OSC input and output.

## Run

```bash
uv sync
uv run entropia
```

The demo opens a particle simulation window and listens for OSC messages on
`127.0.0.1:9000`. Send `/gravity` with two numeric arguments to change the
gravity vector. It sends the particle count to `127.0.0.1:9001` on startup.

Run as a module with `uv run python -m entropia`.
