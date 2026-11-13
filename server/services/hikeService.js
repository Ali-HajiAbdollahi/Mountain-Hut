import { DateTime } from 'luxon';
import { ForbiddenError } from '../errors.js';
import { hikeInput } from '../domain/hikeInput.js';
import { HUT_ZONE } from '../domain/time.js';

export function createHikeService(hikes) {
  return {
    listActive(user) {
      if (user?.role !== 'employee') {
        throw new ForbiddenError('Employee account required');
      }

      const now = DateTime.now()
        .setZone(HUT_ZONE)
        .toFormat('yyyy-MM-dd HH:mm');

      return hikes.listActive(now);
    },

    create(body, user) {
      if (user?.role !== 'hiker') {
        throw new ForbiddenError('Hiker account required');
      }

      const input = hikeInput(body);

      return hikes.atomic(() => {
        const hID = hikes.insert({
          uID: user.uID,
          destination: input.destination,
          route: input.route,
          departure_time: input.departure_time,
          expected_return: input.expected_return,
        });

        hikes.addWaypoints(hID, input.waypoints);
        return hikes.find(hID);
      });
    },
  };
}
