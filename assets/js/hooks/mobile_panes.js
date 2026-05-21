// MobilePanes - LiveView Hook
//
// Drives the mobile two-pane swipe layout. The track element is a
// horizontal scroll-snap container fixed to the viewport on mobile and
// a CSS grid on desktop (the panes use `md:contents` to collapse into
// the grid). On desktop the IntersectionObserver still runs but the
// dot indicators are hidden, so the cost is negligible.
export const MobilePanes = {
  mounted() {
    this.dots = Array.from(document.querySelectorAll('[data-pane-dot]'));
    this.panes = Array.from(this.el.querySelectorAll('[data-pane]'));

    this.dotClickHandlers = [];
    this.dots.forEach(dot => {
      const handler = (event) => {
        event.preventDefault();
        this.scrollToPane(dot.dataset.paneDot);
      };
      dot.addEventListener('click', handler);
      this.dotClickHandlers.push([dot, handler]);
    });

    // Track active pane by raw scroll position. IntersectionObserver with a
    // single threshold races when two panes momentarily sit at exactly 50%,
    // so the active dot can lag or pick the wrong pane. Reading scrollLeft
    // directly is unambiguous.
    if (this.panes.length > 0) {
      this.onScroll = () => {
        const width = this.el.clientWidth;
        if (width === 0) return;
        const idx = Math.round(this.el.scrollLeft / width);
        const pane = this.panes[idx];
        if (pane && pane.dataset.pane !== this.activePane) {
          this.activePane = pane.dataset.pane;
          this.setActiveDot(this.activePane);
        }
      };
      this.el.addEventListener('scroll', this.onScroll, { passive: true });
      // Run once on mount so the dot reflects the initial pane
      this.onScroll();
    }

    // Track the header's bottom edge so the fixed-position track sits
    // exactly under it. The header has variable height (progress bar
    // is conditional, theme switcher row may wrap, etc.).
    this.header = document.querySelector('header');
    if (this.header) {
      this.updateHeaderHeight = () => {
        const rect = this.header.getBoundingClientRect();
        document.documentElement.style.setProperty('--header-h', `${rect.bottom}px`);
      };
      this.updateHeaderHeight();
      this.headerObserver = new ResizeObserver(this.updateHeaderHeight);
      this.headerObserver.observe(this.header);
      window.addEventListener('resize', this.updateHeaderHeight);
    }

    this.lastChallengeOpen = this.el.dataset.challengeOpen;
  },

  updated() {
    // When a challenge opens, pull the user back to the primary pane so
    // the modal lands in context with the tiles rather than over the chat.
    const challengeOpen = this.el.dataset.challengeOpen;
    if (challengeOpen === 'true' && this.lastChallengeOpen !== 'true') {
      this.scrollToPane('primary');
    }
    this.lastChallengeOpen = challengeOpen;
  },

  scrollToPane(name) {
    const pane = this.el.querySelector(`[data-pane="${name}"]`);
    if (!pane) return;
    this.el.scrollTo({ left: pane.offsetLeft, behavior: 'smooth' });
  },

  setActiveDot(name) {
    this.dots.forEach(dot => {
      dot.classList.toggle('active', dot.dataset.paneDot === name);
    });
  },

  destroyed() {
    if (this.onScroll) this.el.removeEventListener('scroll', this.onScroll);
    if (this.headerObserver) this.headerObserver.disconnect();
    if (this.updateHeaderHeight) {
      window.removeEventListener('resize', this.updateHeaderHeight);
    }
    this.dotClickHandlers.forEach(([dot, handler]) => {
      dot.removeEventListener('click', handler);
    });
  }
};
