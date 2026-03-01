export const SoundPlayer = {
  mounted() {
    this.audioCtx = null;

    this.handleEvent("play_sound", ({ sound }) => {
      this.ensureAudioContext();
      if (!this.audioCtx) return;

      if (sound === "chime") {
        this.playChime();
      } else {
        this.playClick();
      }
    });
  },

  ensureAudioContext() {
    if (!this.audioCtx) {
      try {
        this.audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      } catch (_e) {
        // Browser doesn't support Web Audio API
      }
    }
  },

  // Wooden tile clack: noise burst through a bandpass filter for resonance
  playClick() {
    const ctx = this.audioCtx;
    const now = ctx.currentTime;
    const duration = 0.08;

    // White noise buffer
    const bufferSize = Math.ceil(ctx.sampleRate * duration);
    const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < bufferSize; i++) {
      data[i] = Math.random() * 2 - 1;
    }

    const noise = ctx.createBufferSource();
    noise.buffer = buffer;

    // Bandpass filter gives the noise a "woody" pitched resonance
    const filter = ctx.createBiquadFilter();
    filter.type = "bandpass";
    filter.frequency.value = 1800;
    filter.Q.value = 3;

    // Second resonance for body
    const filter2 = ctx.createBiquadFilter();
    filter2.type = "bandpass";
    filter2.frequency.value = 600;
    filter2.Q.value = 2;

    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.4, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + duration);

    const gain2 = ctx.createGain();
    gain2.gain.setValueAtTime(0.25, now);
    gain2.gain.exponentialRampToValueAtTime(0.001, now + duration * 1.2);

    // High resonance path (the sharp "click")
    noise.connect(filter);
    filter.connect(gain);
    gain.connect(ctx.destination);

    // Low resonance path (the woody "body")
    noise.connect(filter2);
    filter2.connect(gain2);
    gain2.connect(ctx.destination);

    noise.start(now);
    noise.stop(now + duration * 1.2);
  },

  // Melodic chime for your-turn notification
  playChime() {
    const ctx = this.audioCtx;
    const now = ctx.currentTime;

    // Two-note ascending chime
    const notes = [
      { freq: 880, delay: 0, duration: 0.15 },
      { freq: 1320, delay: 0.08, duration: 0.18 },
    ];

    notes.forEach(({ freq, delay, duration }) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.type = "sine";
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0, now + delay);
      gain.gain.linearRampToValueAtTime(0.12, now + delay + 0.01);
      gain.gain.exponentialRampToValueAtTime(0.001, now + delay + duration);

      osc.start(now + delay);
      osc.stop(now + delay + duration);
    });
  },
};
