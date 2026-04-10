// Tab Switcher - LiveView Hook
export const TabSwitcher = {
  mounted() {
    this.currentTab = 'podium'; // Default tab
    this.handleTabClickBound = this.handleTabClick.bind(this);
    this.initTabSwitcher();
  },

  updated() {
    // Only skip restore if both the button AND panel already reflect the current tab
    const activeButton = this.el.querySelector(`[data-tab-switcher] .tab-button.active`);
    const activePanel = this.el.querySelector(`#${this.currentTab}-tab`);
    const buttonMatches = activeButton && activeButton.getAttribute('data-tab') === this.currentTab;
    const panelMatches = activePanel && !activePanel.classList.contains('hidden');
    if (buttonMatches && panelMatches) return;
    this.restoreTabState();
  },

  initTabSwitcher() {
    // Find all tab switcher containers within this hook's element
    const tabContainers = this.el.querySelectorAll('[data-tab-switcher]');
    
    tabContainers.forEach(container => {
      const tabButtons = container.querySelectorAll('.tab-button');
      
      // Add click event listeners to all tab buttons
      tabButtons.forEach(button => {
        // Remove existing listeners to prevent duplicates
        button.removeEventListener('click', this.handleTabClickBound);
        button.addEventListener('click', this.handleTabClickBound);
      });
    });
  },

  handleTabClick(event) {
    const clickedTab = event.target;
    const tabName = clickedTab.getAttribute('data-tab');
    
    // Store the current tab state
    this.currentTab = tabName;
    
    // Find the container for this button
    const container = clickedTab.closest('[data-tab-switcher]');
    const tabButtons = container.querySelectorAll('.tab-button');
    const tabPanels = this.el.querySelectorAll('.tab-panel');
    
    // Remove active class from all tab buttons in this container
    tabButtons.forEach(btn => {
      btn.classList.remove('active');
      btn.classList.remove('border-black', 'dark:border-white');
      btn.classList.add('border-transparent');
    });
    
    // Add active class to clicked tab button
    clickedTab.classList.add('active');
    clickedTab.classList.remove('border-transparent');
    clickedTab.classList.add('border-black', 'dark:border-white');
    
    // Hide all tab panels
    tabPanels.forEach(panel => {
      panel.classList.add('hidden');
      panel.classList.remove('active');
    });
    
    // Show the selected tab panel
    const selectedPanel = this.el.querySelector(`#${tabName}-tab`);
    if (selectedPanel) {
      selectedPanel.classList.remove('hidden');
      selectedPanel.classList.add('active');
    }
  },

  restoreTabState() {
    // Only restore if we have a current tab and it's not the default
    if (this.currentTab) {
      const container = this.el.querySelector('[data-tab-switcher]');
      if (container) {
        const tabButtons = container.querySelectorAll('.tab-button');
        const tabPanels = this.el.querySelectorAll('.tab-panel');
        
        // Reset all buttons to inactive state
        tabButtons.forEach(btn => {
          btn.classList.remove('active');
          btn.classList.remove('border-black', 'dark:border-white');
          btn.classList.add('border-transparent');
        });
        
        // Hide all panels
        tabPanels.forEach(panel => {
          panel.classList.add('hidden');
          panel.classList.remove('active');
        });
        
        // Activate the current tab button
        const activeButton = container.querySelector(`[data-tab="${this.currentTab}"]`);
        if (activeButton) {
          activeButton.classList.add('active');
          activeButton.classList.remove('border-transparent');
          activeButton.classList.add('border-black', 'dark:border-white');
        }
        
        // Show the current tab panel
        const activePanel = this.el.querySelector(`#${this.currentTab}-tab`);
        if (activePanel) {
          activePanel.classList.remove('hidden');
          activePanel.classList.add('active');
        }
      }
    }
  },

  destroyed() {
    const tabButtons = this.el.querySelectorAll('.tab-button');
    tabButtons.forEach(button => {
      button.removeEventListener('click', this.handleTabClickBound);
    });
  }
}; 
