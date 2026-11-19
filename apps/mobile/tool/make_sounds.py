"""Sintetiza los sonidos de notificación de AnfYbio (originales, sin licencias)."""
import math, struct, sys, wave

RATE = 44100

def render(name, events, length):
    """events: (inicio_s, frecuencia_hz, volumen, decaimiento_s, parciales)."""
    n = int(RATE * length)
    out = [0.0] * n
    for start, freq, vol, decay, partials in events:
        s0 = int(start * RATE)
        for i in range(s0, n):
            t = (i - s0) / RATE
            env = min(1.0, t / 0.004) * math.exp(-t / decay)  # ataque corto
            if env < 1e-4 and t > 0.05:
                break
            v = 0.0
            for ratio, amp in partials:
                v += amp * math.sin(2 * math.pi * freq * ratio * t)
            out[i] += vol * env * v
    peak = max(abs(x) for x in out) or 1.0
    # Desvanecimiento final para no cortar en seco.
    fade = int(0.05 * RATE)
    for i in range(fade):
        out[n - 1 - i] *= i / fade
    with wave.open(f"{name}.wav", "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(x / peak * 0.85 * 32767)) for x in out))

BELL = [(1.0, 1.0), (2.76, 0.35), (5.40, 0.12)]   # parciales de campana
MARIMBA = [(1.0, 1.0), (4.0, 0.18)]
BEEP = [(1.0, 1.0), (2.0, 0.15)]

# Campanita: dos golpes de campana, Mi6 y Si5.
render("anfybio_campanita", [
    (0.00, 1318.5, 1.0, 0.45, BELL),
    (0.16, 987.8, 0.8, 0.55, BELL),
], 1.6)
# Suave: arpegio ascendente tipo marimba (Do, Mi, Sol, Do).
render("anfybio_suave", [
    (0.00, 523.3, 1.0, 0.30, MARIMBA),
    (0.13, 659.3, 0.9, 0.30, MARIMBA),
    (0.26, 784.0, 0.9, 0.35, MARIMBA),
    (0.39, 1046.5, 0.8, 0.50, MARIMBA),
], 1.5)
# Pulso: tres pitidos cortos y claros.
render("anfybio_pulso", [
    (0.00, 1046.5, 1.0, 0.07, BEEP),
    (0.16, 1046.5, 1.0, 0.07, BEEP),
    (0.32, 1396.9, 1.0, 0.12, BEEP),
], 0.9)
