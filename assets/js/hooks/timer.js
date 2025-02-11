const Timer = {
  mounted() {
    this.totalTime = parseInt(this.el.dataset.totalTime)
    this.timeRemaining = this.totalTime
    this.timerInterval = null
    this.progressRing = this.el.querySelector('.timer-ring-progress')
    this.timerText = this.el.querySelector('.timer-text')
    // this.startBtn = this.el.querySelector('.js-timer-start')
    // this.pauseBtn = this.el.querySelector('.js-timer-pause')
    // this.resumeBtn = this.el.querySelector('.js-timer-resume')
    // this.resetBtn = this.el.querySelector('.js-timer-reset')

    // this.startBtn.addEventListener('click', () => this.startTimer())
    // this.pauseBtn.addEventListener('click', () => this.pauseTimer())
    // this.resumeBtn.addEventListener('click', () => this.resumeTimer())
    // this.resetBtn.addEventListener('click', () => this.resetTimer())

	console.log("autostart: " + this.el.dataset.autostart)
	if (this.el.dataset.autostart) {
		// Hide the start button and show pause button immediately
		// this.el.querySelector('.js-timer-start')?.classList.add('hidden')
		// this.el.querySelector('.js-timer-pause')?.classList.remove('hidden')
		// Start the timer automatically
		this.resetTimer()
		this.startTimer()
	}
  },

  startTimer() {
	clearInterval(this.timerInterval)
    this.timeRemaining = this.totalTime
    this.updateDisplay()
    // this.startBtn.classList.add('hidden')
    // this.pauseBtn.classList.remove('hidden')
    // this.resumeBtn.classList.add('hidden')
    
    this.timerInterval = setInterval(() => this.tick(), 1000)
  },

  pauseTimer() {
    clearInterval(this.timerInterval)
    // this.pauseBtn.classList.add('hidden')
    // this.resumeBtn.classList.remove('hidden')
  },

  resumeTimer() {
    // this.resumeBtn.classList.add('hidden')
    // this.pauseBtn.classList.remove('hidden')
    this.timerInterval = setInterval(() => this.tick(), 1000)
  },

  resetTimer() {
    clearInterval(this.timerInterval)
    this.timeRemaining = this.totalTime
    this.updateDisplay()
    // this.startBtn.classList.remove('hidden')
    // this.pauseBtn.classList.add('hidden')
    // this.resumeBtn.classList.add('hidden')
  },

  tick() {
    this.timeRemaining--
    if (this.timeRemaining <= 0) {
      clearInterval(this.timerInterval)
      this.timeRemaining = 0
      this.pushEvent('timer_complete', {id: this.el.id})
    //   this.startBtn.classList.remove('hidden')
    //   this.pauseBtn.classList.add('hidden')
    }
    
    this.updateDisplay()
  },

  updateDisplay() {
	const percentage = (this.timeRemaining / this.totalTime) * 100
	const circle = this.progressRing
	const dashArray = circle.getAttribute('stroke-dasharray')
	const dashOffset = dashArray * (percentage / 100)
	this.progressRing.setAttribute('stroke-dashoffset', dashOffset)
	// this.timerText.textContent = this.formatTime(this.timeRemaining)
  },

  formatTime(seconds) {
    const minutes = Math.floor(seconds / 60)
    const remainingSeconds = seconds % 60
    return `${String(minutes).padStart(2, '0')}:${String(remainingSeconds).padStart(2, '0')}`
  },

  destroyed() {
    if (this.timerInterval) {
      clearInterval(this.timerInterval)
    }
  }
}

export default Timer; 