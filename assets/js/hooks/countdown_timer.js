export const CountdownTimer = {
  mounted() {
    this.circumference = 2 * Math.PI * 10; // r=10
    this.fg = this.el.querySelector(".countdown-circle-fg");
    this.duration = parseInt(this.el.dataset.duration);
    this.epoch = this.el.dataset.epoch;
    this.paused = this.el.dataset.paused === "true";
    this.animId = null;

    if (this.paused) {
      this.setProgress(1);
    } else {
      this.startCountdown();
    }
  },

  updated() {
    const newEpoch = this.el.dataset.epoch;
    const newPaused = this.el.dataset.paused === "true";
    const newDuration = parseInt(this.el.dataset.duration);

    const epochChanged = newEpoch !== this.epoch;
    const unpaused = this.paused && !newPaused;

    this.epoch = newEpoch;
    this.paused = newPaused;
    this.duration = newDuration;

    if (this.paused) {
      this.cancelAnimation();
      this.setProgress(1);
    } else if (epochChanged || unpaused) {
      this.startCountdown();
    }
  },

  destroyed() {
    this.cancelAnimation();
  },

  startCountdown() {
    this.cancelAnimation();
    this.startTime = performance.now();

    const tick = (now) => {
      const elapsed = now - this.startTime;
      const fraction = Math.max(0, 1 - elapsed / this.duration);
      this.setProgress(fraction);

      if (fraction > 0) {
        this.animId = requestAnimationFrame(tick);
      }
    };

    this.animId = requestAnimationFrame(tick);
  },

  cancelAnimation() {
    if (this.animId) {
      cancelAnimationFrame(this.animId);
      this.animId = null;
    }
  },

  setProgress(fraction) {
    if (this.fg) {
      this.fg.style.strokeDashoffset = this.circumference * (1 - fraction);
    }
  }
};
