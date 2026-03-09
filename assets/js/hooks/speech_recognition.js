export const SpeechRecognition = {
  mounted() {
    if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
      console.warn('Speech recognition not supported in this browser');
      this.pushEvent("speech_error", { error: "Speech recognition not supported" });
      return;
    }

    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    this.recognition = new SpeechRecognition();
    this.isRunning = false;
    this.startAttempted = false;

    this.recognition.continuous = false;
    this.recognition.interimResults = false;
    this.recognition.maxAlternatives = 3;
    this.recognition.lang = 'en-US';

    this.recognition.onstart = () => {
      this.isRunning = true;
      this.startAttempted = false;
      this.pushEvent("speech_started");
    };

    this.recognition.onresult = (event) => {
      const results = [];
      for (let i = 0; i < event.results.length; i++) {
        const result = event.results[i];
        for (let j = 0; j < result.length; j++) {
          const alternative = result[j];
          results.push({
            transcript: alternative.transcript.trim().toLowerCase(),
            confidence: alternative.confidence
          });
        }
      }

      this.pushEvent("speech_results", { results: results });
    };

    this.recognition.onerror = (event) => {
      let errorMessage = "Speech recognition error";
      
      switch (event.error) {
        case 'no-speech':
          errorMessage = "No speech detected. Please try again.";
          break;
        case 'audio-capture':
          errorMessage = "Microphone not found. Please check your microphone.";
          break;
        case 'not-allowed':
          errorMessage = "Microphone permission denied. Please allow microphone access.";
          break;
        case 'network':
          errorMessage = "Network error. Please check your connection.";
          break;
        default:
          errorMessage = `Speech recognition error: ${event.error}`;
      }

      this.pushEvent("speech_error", { error: errorMessage });
    };

    this.recognition.onspeechend = () => {
      this.recognition.stop();
    };

    this.recognition.onend = () => {
      this.isRunning = false;
      this.pushEvent("speech_ended");
    };

    this.handleEvent("start_recognition", ({ phrases = [] }) => {
      if (this.recognition) {
        this.applyContextualBiasing(phrases);

        if (this.isRunning) {
          this.recognition.stop();
        }

        setTimeout(() => {
          try {
            this.recognition.start();
            this.startAttempted = true;
          } catch (startError) {
            this.startAttempted = false;
            if (startError.name === 'NotAllowedError') {
              this.pushEvent("speech_error", { error: "Microphone permission denied" });
            } else if (startError.name === 'InvalidStateError') {
              this.pushEvent("speech_error", { error: "Speech recognition is already active" });
            } else {
              this.pushEvent("speech_error", { error: `Speech recognition error: ${startError.message}` });
            }
          }
        }, 100);
        setTimeout(() => {
          if (this.startAttempted && !this.isRunning) {
            this.pushEvent("speech_error", { error: "Speech recognition failed to start" });
          }
        }, 1000);
      } else {
        this.pushEvent("speech_error", { error: "Speech recognition not initialized" });
      }
    });

    this.handleEvent("stop_recognition", () => {
      if (this.recognition) {
        this.recognition.stop();
        this.isRunning = false;
      }
    });
  },

  destroyed() {
    if (this.recognition) {
      this.recognition.stop();
    }
  },

  applyContextualBiasing(phrases) {
    const cleanedPhrases = phrases
      .map((phrase) => phrase.trim())
      .filter((phrase) => phrase.length > 0);

    if ("phrases" in this.recognition) {
      this.recognition.phrases = cleanedPhrases.map((phrase) => ({
        phrase,
        boost: 5.0
      }));
      return;
    }

    const GrammarList = window.SpeechGrammarList || window.webkitSpeechGrammarList;
    if (!GrammarList || cleanedPhrases.length === 0) {
      return;
    }

    const grammar = `#JSGF V1.0; grammar piratex; public <phrase> = ${cleanedPhrases.join(" | ")} ;`;
    const grammarList = new GrammarList();
    grammarList.addFromString(grammar, 1);
    this.recognition.grammars = grammarList;
  }
};
