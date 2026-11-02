import { DateTime } from 'luxon';
import { ValidationError } from '../errors.js';

function validateInput({ date, time, partySize }) {
  if (typeof date !== 'string') {
    throw new ValidationError('date is required');
  }

  const parsedDate = DateTime.fromFormat(date, 'yyyy-MM-dd', { zone: 'utc' });
  if (!parsedDate.isValid || parsedDate.toFormat('yyyy-MM-dd') !== date) {
    throw new ValidationError('date must use YYYY-MM-DD format');
  }

  if (typeof time !== 'string' || !/^\d{2}:\d{2}$/.test(time)) {
    throw new ValidationError('time must use HH:mm format');
  }

  const parsedTime = DateTime.fromFormat(
    `${date} ${time}`,
    'yyyy-MM-dd HH:mm',
    { zone: 'utc' },
  );
  if (!parsedTime.isValid || parsedTime.toFormat('HH:mm') !== time) {
    throw new ValidationError('time must be a valid 24-hour time');
  }

  const sizeText = String(partySize);
  if (!/^[1-9]\d*$/.test(sizeText) || !Number.isSafeInteger(Number(sizeText))) {
    throw new ValidationError('partySize must be a positive integer');
  }

  return Number(sizeText);
}

export function createAvailabilityService(availabilityDao) {
  return {
    check({ date, time, partySize }) {
      const people = validateInput({ date, time, partySize });
      const startTime = `${date} ${time}`;
      const slot = availabilityDao.findByStartTime(startTime);

      if (!slot) {
        return {
          available: false,
          partySize: people,
          slot: null,
          allocation: [],
        };
      }

      const freeSeats = slot.tables.reduce(
        (total, table) => total + table.freeSeats,
        0,
      );

      if (freeSeats < people) {
        return {
          available: false,
          partySize: people,
          slot: {
            tsID: slot.tsID,
            start_time: slot.start_time,
            end_time: slot.end_time,
          },
          allocation: [],
        };
      }

      const singleTable = slot.tables
        .filter(table => table.freeSeats >= people)
        .sort((a, b) => a.freeSeats - b.freeSeats || a.table_no - b.table_no)[0];

      let allocation;

      if (singleTable) {
        allocation = [{
          table_no: singleTable.table_no,
          seats: people,
        }];
      } else {
        let remaining = people;
        allocation = [];

        for (const table of slot.tables) {
          if (remaining === 0) break;

          const seats = Math.min(table.freeSeats, remaining);
          if (seats > 0) {
            allocation.push({
              table_no: table.table_no,
              seats,
            });
            remaining -= seats;
          }
        }
      }

      return {
        available: true,
        partySize: people,
        slot: {
          tsID: slot.tsID,
          start_time: slot.start_time,
          end_time: slot.end_time,
        },
        allocation,
      };
    },
  };
}
