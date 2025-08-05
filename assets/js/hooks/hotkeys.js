export const Hotkeys = {
	// NOTE: this setup hits the server every time a key in the hotkeys set is pressed.
	// This is not ideal, but it's a good start.
	mounted() {
	  window.addEventListener("keydown", (event) => {
		// ignore event from forms/text inputs. We actually DONT do this
		// and instead only use non-letters as hotkeys.
		// if (["INPUT", "SELECT", "TEXTAREA"].includes(event.target.tagName)) return;

		// hitting Enter focuses on the word input text box
		if (["Enter"].includes(event.key)) {
			document.getElementById("new_word_input").focus();
		}

		// minimize hotkey handling to only the ones we care about
		if (!([" ", "Escape", "0", "1", "2", "3", "6", "7", "8"].includes(event.key))) return;

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
	  });
	}
  };