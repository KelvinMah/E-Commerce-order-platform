import { describe, expect, it } from 'vitest';
import { money } from './api';
describe('currency formatting', () => {
  it('formats integer cents without floating-point checkout calculations', () => {
    expect(money(1250)).toContain('12.50');
  });
});
