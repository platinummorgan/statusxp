// Test the exact structure from steam-sync
for (let i = 0; i < 5; i++) {
  if (true) {
    for (let j = 0; j < 3; j++) {
      const item = j;
      
      let gameTitle = null;
      
      try {
        console.log('processing', item);
        
        if (item === 1) {
          continue;
        }
        
        gameTitle = { id: item };
        
      } catch (error) {
        console.error('error:', error);
      }
    }
  }
}

console.log('Structure is valid!');
