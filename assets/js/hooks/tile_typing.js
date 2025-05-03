export const TileTyping = {
	// mounted() {
	// 	this.el.classList.add('flip');
	// 	this.el.addEventListener('animationend', () => {
	// 		this.el.classList.remove('flip');
	// 	});
	// }

	mounted() {
		const index = parseInt(this.el.dataset.index);
		setTimeout(() => {
			this.el.classList.add('flip');
			this.el.addEventListener('animationend', () => {
				this.el.classList.remove('flip');
			});
		}, index * 200);
	}
  };