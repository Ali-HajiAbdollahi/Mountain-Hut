// MH-10 Define menus — unit tests (menu input + service with fake DAO)
import { describe, it, expect, vi } from 'vitest';
import { slotMenuInput } from '../../domain/slotMenuInput.js';
import { createSlotService } from '../../services/slotService.js';
import { NotFoundError, ValidationError } from '../../errors.js';

const formatted = '<strong>Lunch</strong><br>• Soup<br>  • <em>with croutons</em>';

describe('slotMenuInput', () => {
  it('accepts free text and returns it trimmed', () => {
    expect(slotMenuInput({ menu: '  Polenta with mushrooms \n' })).toBe('Polenta with mushrooms');
  });

  it('keeps the formatting (bold, italic, list and sub-items) unchanged', () => {
    expect(slotMenuInput({ menu: formatted })).toBe(formatted);
  });

  it.each([
    ['missing', {}],
    ['empty', { menu: '' }],
    ['only spaces', { menu: '   \n ' }],
    ['a number', { menu: 42 }],
    ['null', { menu: null }],
  ])('rejects a menu that is %s', (_, body) => {
    expect(() => slotMenuInput(body)).toThrow('menu must be a non-empty string');
  });

  it('rejects unknown fields and bodies that are not objects', () => {
    expect(() => slotMenuInput({ menu: 'Soup', tsID: 3 })).toThrow('Unexpected field');
    expect(() => slotMenuInput(null)).toThrow(ValidationError);
    expect(() => slotMenuInput(['Soup'])).toThrow(ValidationError);
  });
});

describe('slotService.publishMenu', () => {
  function fakeDao(saved = { tsID: 3, menu: 'Soup' }) {
    return { saveSlotMenu: vi.fn(() => saved) };
  }

  it('saves the trimmed menu for the slot and returns it', () => {
    const dao = fakeDao({ tsID: 3, menu: 'Soup' });
    expect(createSlotService(dao).publishMenu(3, { menu: ' Soup ' })).toEqual({ tsID: 3, menu: 'Soup' });
    expect(dao.saveSlotMenu).toHaveBeenCalledWith(3, 'Soup');
  });

  it('throws NotFoundError when the slot does not exist', () => {
    expect(() => createSlotService(fakeDao(null)).publishMenu(99, { menu: 'Soup' })).toThrow(NotFoundError);
  });

  it('does not touch the database when the menu is invalid', () => {
    const dao = fakeDao();
    expect(() => createSlotService(dao).publishMenu(3, { menu: ' ' })).toThrow(ValidationError);
    expect(dao.saveSlotMenu).not.toHaveBeenCalled();
  });
});

describe('slotService.recentMenus', () => {
  const rows = [
    { tsID: 5, start_time: '2026-12-02 19:00', end_time: '2026-12-02 20:00', menu: 'Venison stew' },
    { tsID: 2, start_time: '2026-11-30 12:00', end_time: '2026-11-30 13:00', menu: 'Polenta' },
  ];

  it('asks the DAO for the menus before the given time and returns them unchanged', () => {
    const dao = { recentMenus: vi.fn(() => rows) };
    expect(createSlotService(dao).recentMenus('2026-12-03 12:00')).toEqual(rows);
    expect(dao.recentMenus).toHaveBeenCalledWith('2026-12-03 12:00');
  });

  it.each([undefined, '2026-12-03', '2026-12-03T12:00', '03/12/2026 12:00', '2026-02-30 12:00'])(
    'rejects the reference time %s without querying the database', before => {
      const dao = { recentMenus: vi.fn() };
      expect(() => createSlotService(dao).recentMenus(before)).toThrow(ValidationError);
      expect(dao.recentMenus).not.toHaveBeenCalled();
    });
});
