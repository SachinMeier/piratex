export const Hotkeys = {
	// NOTE: this setup hits the server every time a key in the hotkeys set is pressed.
	// This is not ideal, but it's a good start.
	mounted() {
	  this.handleKeydown = (event) => {
		// ignore event from forms/text inputs. We actually DONT do this
		// and instead only use non-letters as hotkeys.
		// if (["INPUT", "SELECT", "TEXTAREA"].includes(event.target.tagName)) return;

		// hitting Enter focuses on the word input text box
		if (["Enter"].includes(event.key)) {
			const newWordInput = document.getElementById("new_word_input");
			if (newWordInput) {
				newWordInput.focus();
			}
		}

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
