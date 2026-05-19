// FitRowOrStack - LiveView Hook
//
// Lays the element's direct children out in a horizontal row when they
// all fit within the element's width, and stacks them vertically when
// they don't. Used for the Best Steal card: "old word -> new word" stays
// on one line when there's room, otherwise each word drops onto its own
// line (and scrolls individually via its own overflow-x).
//
// When there are exactly three children (word, arrow, word) the middle
// one is rotated 90deg while stacked so the connecting arrow points down.
export const FitRowOrStack = {
  mounted() {
    this.evaluate();
    this.resizeObserver = new ResizeObserver(() => this.evaluate());
    this.resizeObserver.observe(this.el);
  },

  updated() {
    this.evaluate();
  },

  destroyed() {
    if (this.resizeObserver) this.resizeObserver.disconnect();
  },

  evaluate() {
    const items = Array.from(this.el.children);
    if (items.length < 2) return;

    // scrollWidth reports each child's natural content width even when the
    // child is itself an overflow-x scroller, so this measures the true
    // horizontal space a single-row layout would need.
    const gap = parseFloat(getComputedStyle(this.el).columnGap) || 0;
    const needed =
      items.reduce((sum, el) => sum + el.scrollWidth, 0) +
      gap * (items.length - 1);
    const fits = needed <= this.el.clientWidth;

    this.el.classList.toggle('flex-row', fits);
    this.el.classList.toggle('flex-col', !fits);

    // Point the connecting arrow (middle of three) down when stacked.
    if (items.length === 3) {
      items[1].style.transform = fits ? '' : 'rotate(90deg)';
    }
  }
};
