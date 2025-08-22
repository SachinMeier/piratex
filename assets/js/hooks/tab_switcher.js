// Tab Switcher - Raw JavaScript (no LiveView dependencies)
document.addEventListener('DOMContentLoaded', function() {
  // Find all tab switcher containers
  const tabContainers = document.querySelectorAll('[data-tab-switcher]');
  
  tabContainers.forEach(container => {
    const tabButtons = container.querySelectorAll('.tab-button');
    const tabPanels = document.querySelectorAll('.tab-panel');
    
    // Add click event listeners to all tab buttons
    tabButtons.forEach(button => {
      button.addEventListener('click', function(event) {
        const clickedTab = event.target;
        const tabName = clickedTab.getAttribute('data-tab');
        
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
        const selectedPanel = document.getElementById(`${tabName}-tab`);
        if (selectedPanel) {
          selectedPanel.classList.remove('hidden');
          selectedPanel.classList.add('active');
        }
      });
    });
  });
}); 