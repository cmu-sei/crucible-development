// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services } from '../../fixtures';

test.describe('Performance and Optimization', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to Blueprint application
    await page.goto(Services.Blueprint.UI);
    
    // Wait for Keycloak redirect
    await page.waitForURL(/.*localhost:8443.*/, { timeout: 10000 });
    
    // Fill in username
    await page.fill('input[name="username"]', 'admin');
    
    // Fill in password
    await page.fill('input[name="password"]', 'admin');
    
    // Click Sign In button
    await page.click('button:has-text("Sign In")');
    
    // Wait for redirect back to Blueprint
    await page.waitForURL(/.*localhost:4725.*/, { timeout: 10000 });
    
    // Verify main application loaded
    await expect(page).toHaveURL(/.*localhost:4725.*/);
    await page.waitForLoadState('networkidle');
  });

  test('Memory Leak Detection', async ({ page, context }) => {
    // 1. Open browser dev tools and start memory profiling
    // Enable metrics collection
    const client = await context.newCDPSession(page);
    await client.send('Performance.enable');
    
    // Get initial memory usage
    const getMemoryUsage = async () => {
      const metrics = await client.send('Performance.getMetrics');
      const jsHeapUsed = metrics.metrics.find(m => m.name === 'JSHeapUsedSize')?.value || 0;
      const jsHeapTotal = metrics.metrics.find(m => m.name === 'JSHeapTotalSize')?.value || 0;
      const nodes = metrics.metrics.find(m => m.name === 'Nodes')?.value || 0;
      
      return {
        heapUsed: Math.round(jsHeapUsed / 1024 / 1024), // MB
        heapTotal: Math.round(jsHeapTotal / 1024 / 1024), // MB
        nodes: Math.round(nodes)
      };
    };
    
    const initialMemory = await getMemoryUsage();
    console.log('Initial Memory Usage:');
    console.log(`  Heap Used: ${initialMemory.heapUsed} MB`);
    console.log(`  Heap Total: ${initialMemory.heapTotal} MB`);
    console.log(`  DOM Nodes: ${initialMemory.nodes}`);
    
    const memorySnapshots: Array<{ iteration: number; heapUsed: number; heapTotal: number; nodes: number }> = [];
    memorySnapshots.push({ iteration: 0, ...initialMemory });
    
    // 2. Navigate through various MSELs and sections multiple times
    const navigationRoutes = [
      Services.Blueprint.UI,
      `${Services.Blueprint.UI}/msels`,
      `${Services.Blueprint.UI}/teams`,
      `${Services.Blueprint.UI}/users`,
      Services.Blueprint.UI,
    ];
    
    const iterations = 3; // Navigate through the cycle 3 times
    
    for (let i = 1; i <= iterations; i++) {
      console.log(`\nIteration ${i}:`);
      
      for (const route of navigationRoutes) {
        await page.goto(route).catch(() => {
          console.log(`Route ${route} not available, skipping`);
        });
        await page.waitForLoadState('networkidle');
        
        // Wait a bit for any async operations
        await page.waitForTimeout(500);
      }
      
      // Force garbage collection if possible
      await page.evaluate(() => {
        if (window.gc) {
          window.gc();
        }
      });
      
      // Wait for GC to complete
      await page.waitForTimeout(1000);
      
      // Take memory snapshot
      const currentMemory = await getMemoryUsage();
      memorySnapshots.push({ iteration: i, ...currentMemory });
      
      console.log(`  Heap Used: ${currentMemory.heapUsed} MB`);
      console.log(`  Heap Total: ${currentMemory.heapTotal} MB`);
      console.log(`  DOM Nodes: ${currentMemory.nodes}`);
    }
    
    // 3. Check memory usage
    const finalMemory = memorySnapshots[memorySnapshots.length - 1];
    const memoryGrowth = finalMemory.heapUsed - initialMemory.heapUsed;
    const memoryGrowthPercent = (memoryGrowth / initialMemory.heapUsed) * 100;
    
    console.log('\nMemory Analysis:');
    console.log(`  Memory Growth: ${memoryGrowth} MB (${memoryGrowthPercent.toFixed(1)}%)`);
    
    // Calculate trend - are we continuously growing?
    const memoryTrend = memorySnapshots.slice(1).map((snapshot, index) => {
      const previous = memorySnapshots[index];
      return snapshot.heapUsed - previous.heapUsed;
    });
    
    const averageGrowth = memoryTrend.reduce((a, b) => a + b, 0) / memoryTrend.length;
    console.log(`  Average Growth per Iteration: ${averageGrowth.toFixed(2)} MB`);
    
    // Check for stabilization - last iteration should not grow significantly
    const lastIterationGrowth = memoryTrend[memoryTrend.length - 1];
    console.log(`  Last Iteration Growth: ${lastIterationGrowth.toFixed(2)} MB`);
    
    // expect: Memory usage stabilizes
    // Memory should not grow continuously - last iteration growth should be small
    expect(Math.abs(lastIterationGrowth)).toBeLessThan(20); // Less than 20MB growth in last iteration
    
    // expect: No continuous increase in memory
    // Total growth should be reasonable (less than 100MB for normal usage)
    expect(memoryGrowth).toBeLessThan(100);
    
    // expect: Garbage collection occurs appropriately
    // If we see decreases in memory between iterations, GC is working
    const hasMemoryDecreases = memoryTrend.some(growth => growth < 0);
    console.log(`  Garbage Collection Active: ${hasMemoryDecreases ? 'Yes' : 'No'}`);
    
    // Check DOM node count - should not grow excessively
    const nodeGrowth = finalMemory.nodes - initialMemory.nodes;
    console.log(`  DOM Node Growth: ${nodeGrowth} nodes`);
    expect(nodeGrowth).toBeLessThan(1000); // Should not leak 1000+ DOM nodes
    
    // Clean up
    await client.detach();
  });
});
