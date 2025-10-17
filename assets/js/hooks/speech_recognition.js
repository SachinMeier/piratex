export const SpeechRecognition = {
  // TODO: consider adding a list of common homophones of proper nouns to improve the accuracy of speech recognition
  // this might be an impossible task.
  // https://developer.mozilla.org/en-US/docs/Web/API/Web_Speech_API/Using_the_Web_Speech_API#contextual_biasing_in_speech_recognition

  mounted() {
    // console.log("SpeechRecognition hook mounted");
    // Check if Web Speech API is supported
    if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
      console.warn('Speech recognition not supported in this browser');
      this.pushEvent("speech_error", { error: "Speech recognition not supported" });
      return;
    }

    console.log("Web Speech API is supported, initializing...");
    // Initialize speech recognition
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    this.recognition = new SpeechRecognition();
    this.isRunning = false;
    this.startAttempted = false;
    console.log("Speech recognition object created:", this.recognition);
    
    // Configure recognition settings
    this.recognition.continuous = false;
    this.recognition.interimResults = false;
    this.recognition.maxAlternatives = 3;
    this.recognition.lang = 'en-US';
    
    // Add debugging for recognition state
    // console.log("Speech recognition configured:", {
    //   continuous: this.recognition.continuous,
    //   interimResults: this.recognition.interimResults,
    //   maxAlternatives: this.recognition.maxAlternatives,
    //   lang: this.recognition.lang
    // });

    // Event handlers
    this.recognition.onstart = () => {
      // console.log("Speech recognition started successfully");
      this.isRunning = true;
      this.startAttempted = false; // Clear the flag since we started successfully
      this.pushEvent("speech_started");
    };

    this.recognition.onresult = (event) => {
      const results = [];

      // console.log("Speech recognition result event:", event);
      // console.log("Number of results:", event.results.length);
      console.log("Raw results:", event.results);
      
      // Extract all alternatives from the result.
      for (let i = 0; i < event.results.length; i++) {
        const result = event.results[i];
        // console.log(`Result ${i}:`, result);
        // console.log(`Result ${i} length:`, result.length);
        // console.log(`Result ${i} isFinal:`, result.isFinal);
        
        for (let j = 0; j < result.length; j++) {
          const alternative = result[j];
          // console.log(`Alternative ${j}:`, alternative);
          results.push({
            transcript: alternative.transcript.trim().toLowerCase(),
            confidence: alternative.confidence
          });
        }
      }

      console.log("Processed speech recognition results:", results);

      this.pushEvent("speech_results", { results: results });
    };

    this.recognition.onerror = (event) => {
      console.log("Speech recognition error event:", event);
      console.log("Error type:", event.error);
      console.log("Error details:", event);
      let errorMessage = "Speech recognition error";
      
      switch (event.error) {
        case 'no-speech':
          errorMessage = "No speech detected. Please try again.";
          console.log("No speech detected - this is normal if user doesn't speak");
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
      // console.log("Speech recognition ended");
      this.isRunning = false;
      this.pushEvent("speech_ended");
    };

    this.recognition.onnomatch = () => {
      // console.log("Speech recognition no match");
      // this.pushEvent("speech_no_match");
    };

    // Handle LiveView push events
    this.handleEvent("start_recognition", () => {
      // console.log("Received start_recognition event");
      if (this.recognition) {
        // console.log("Speech recognition object exists, isRunning:", this.isRunning);
        
        // Always stop first to ensure clean state
        if (this.isRunning) {
          // console.log("Speech recognition already running, stopping first");
          this.recognition.stop();
        }
        
        // Wait a moment to ensure clean state, then start
        setTimeout(() => {
          // console.log("Attempting to start speech recognition");
          try {
            this.recognition.start();
            // console.log("recognition.start() called successfully");
            this.startAttempted = true;
          } catch (startError) {
            // console.log("Caught error from recognition.start():", startError);
            this.startAttempted = false;
            
            // Handle specific error types
            if (startError.name === 'NotAllowedError') {
              this.pushEvent("speech_error", { error: "Microphone permission denied" });
            } else if (startError.name === 'InvalidStateError') {
              // This shouldn't happen now, but just in case
              // console.log("InvalidStateError - recognition might still be starting");
              this.pushEvent("speech_error", { error: "Speech recognition is already active" });
            } else {
              this.pushEvent("speech_error", { error: `Speech recognition error: ${startError.message}` });
            }
          }
        }, 100);
        
        // Set a timeout to check if speech recognition actually started
        setTimeout(() => {
          if (this.startAttempted && !this.isRunning) {
            // console.log("Speech recognition didn't start within timeout");
            this.pushEvent("speech_error", { error: "Speech recognition failed to start" });
          }
        }, 1000);
      } else {
        // console.error("Speech recognition object not found");
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
    console.log("SpeechRecognition hook destroyed");
    if (this.recognition) {
      this.recognition.stop();
    }
  }
};