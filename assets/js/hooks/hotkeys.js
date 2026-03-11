export const Hotkeys = {
	// NOTE: this setup hits the server every time a key in the hotkeys set is pressed.
	// This is not ideal, but it's a good start.
	mounted() {
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

		// Keep normal typing behavior in editable fields except that space still
		// acts as the flip hotkey when the main word input is focused.
		if (isFormTarget && !(isWordInput && event.key === " ")) return;

		// minimize hotkey handling to only the ones we care about
		if (!([" ", "Escape", "0", "1", "2", "3", "5", "6", "7", "8"].includes(event.key))) return;

		// prevent default behavior of space bar (page scroll)
		event.preventDefault();

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
