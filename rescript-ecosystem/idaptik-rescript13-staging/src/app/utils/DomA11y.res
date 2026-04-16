// SPDX-License-Identifier: PMPL-1.0-or-later
// DomA11y.res - DOM accessibility utilities
//
// Utilities for ARIA live regions, OS preference detection, and
// accessibility features

// Check if user prefers reduced motion
let prefersReducedMotion = (): bool => {
  %raw(`typeof window !== 'undefined' && window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches`)
}

// Check if user prefers high contrast
let prefersHighContrast = (): bool => {
  %raw(`typeof window !== 'undefined' && window.matchMedia && (window.matchMedia('(prefers-contrast: high)').matches || window.matchMedia('(prefers-contrast: more)').matches)`)
}

// Listen for reduced motion preference changes
@warning("-27")
let onReducedMotionChange = (callback: bool => unit): unit => {
  %raw(`
    (function() {
      if (typeof window !== 'undefined' && window.matchMedia) {
        const query = window.matchMedia('(prefers-reduced-motion: reduce)');
        const handler = (e) => callback(e.matches);
        query.addEventListener('change', handler);
      }
    })()
  `)
}

// Create ARIA live region in DOM
@warning("-27")
let createLiveRegion = (id: string, politeness: string): unit => {
  %raw(`
    (function() {
      if (typeof document !== 'undefined') {
        if (!document.getElementById(id)) {
          const region = document.createElement('div');
          region.id = id;
          region.setAttribute('role', 'status');
          region.setAttribute('aria-live', politeness);
          region.setAttribute('aria-atomic', 'true');
          region.style.position = 'absolute';
          region.style.left = '-10000px';
          region.style.width = '1px';
          region.style.height = '1px';
          region.style.overflow = 'hidden';
          document.body.appendChild(region);
        }
      }
    })()
  `)
}

// Announce message to screen reader via live region
@warning("-27")
let announce = (message: string, regionId: string): unit => {
  %raw(`
    (function() {
      if (typeof document !== 'undefined') {
        const region = document.getElementById(regionId);
        if (region) {
          region.textContent = message;
        }
      }
    })()
  `)
}
