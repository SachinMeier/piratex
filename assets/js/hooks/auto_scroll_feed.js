export const AutoScrollFeed = {
  mounted() {
    this.handleScroll = () => {
      this.shouldStickToBottom = this.isNearBottom();
    };

    this.shouldStickToBottom = true;
    this.el.addEventListener("scroll", this.handleScroll, { passive: true });
    this.scrollToBottom();
  },

  updated() {
    if (this.shouldStickToBottom) {
      this.scrollToBottom();
    }
  },

  destroyed() {
    this.el.removeEventListener("scroll", this.handleScroll);
  },

  isNearBottom() {
    return this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight < 48;
  },

  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight;
    this.shouldStickToBottom = true;
  }
};
