export const Hotkeys = {
	// NOTE: this setup hits the server every time a key in the hotkeys set is pressed.
	// This is not ideal, but it's a good start.
	mounted() {
	  this.lastHotkeyTime = {};

	  this.handleKeydown = (event) => {
		const isFormTarget = ["INPUT", "SELECT", "TEXTAREA"].includes(event.target.tagName) || event.target.isContentEditable;
		const isWordInput = event.target.id === "new_word_input";
		const isChatInput = event.target.id === "chat_message_input";

		// hitting Enter focuses on the word input text box unless chat is active
		if (event.key === "Enter" && !isChatInput) {
			const newWordInput = document.getElementById("new_word_input");
			if (newWordInput) {
				newWordInput.focus();
			}
		}

		// Hotkey keys that should be intercepted even when the word input is focused.
		// Numbers are hotkeys (not valid word characters), and space triggers flip.
		const hotkeyKeys = [" ", "Escape", "0", "1", "2", "3", "6", "7", "8"];

		// Keep normal typing in editable fields, but intercept hotkeys in word input.
		if (isFormTarget && !(isWordInput && hotkeyKeys.includes(event.key))) return;

		// Ignore keys that aren't in the hotkey set.
		if (!hotkeyKeys.includes(event.key)) return;

		// prevent default behavior of space bar (page scroll)
		event.preventDefault();

		// throttle repeated hotkey presses to avoid flooding the server
		const now = Date.now();
		const throttleMs = 300;
		if (this.lastHotkeyTime[event.key] && now - this.lastHotkeyTime[event.key] < throttleMs) return;
		this.lastHotkeyTime[event.key] = now;

		this.pushEvent("hotkey", {
		  key: event.key,
		  // unused for now
		  ctrl: event.ctrlKey,
		  shift: event.shiftKey,
		  alt: event.altKey,
		  meta: event.metaKey
		});
	  };

	  window.addEventListener("keydown", this.handleKeydown);
	},

	destroyed() {
	  if (this.handleKeydown) {
		window.removeEventListener("keydown", this.handleKeydown);
	  }
	}
  };
