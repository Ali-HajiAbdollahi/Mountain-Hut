
TEMPLATE FOR RETROSPECTIVE (Team 05)
====================================

## PROCESS MEASURES

### Macro statistics

- Number of stories committed vs done : 6 vs 6
- Total points committed vs done : 24 vs 24
- Nr of hours planned vs spent (as a team) : 98h 00m vs 98h 25m

### Detailed statistics

| Story                         | # Tasks      | Points       | Hours est.        | Hours actual      |
| ----------------------------- | ------------ | ------------ | ----------------- | ----------------- |
| _#0_                          | 10           | -            | 23h 00m           | 22h 55m           |
| MH-8 Cancel a booking         | 9            | 3            | 9h 15m            | 8h 55m            |
| MH-9 Repeat a weekly schedule | 11           | 5            | 15h 00m           | 16h 05m           |
| MH-10 Define menus            | 10           | 3            | 11h 00m           | 12h 25m           |
| MH-11 View meal details       | 8            | 2            | 10h 30m           | 10h 25m           |
| MH-20 Register a hike        | 11           | 8            | 16h 15m           | 15h 50m           |
| MH-21 View active hikes      | 10           | 3            | 13h 00m           | 11h 50m           |
| **Total**               | **69** | **24** | **98h 00m** | **98h 25m** |

- Hours per task  <span style="color:red">per person</span>  (average, standard deviation)
  * 1.14h average, 0.65h standard deviation (hours spent)
  * A task with several assignees is counted once per assignee, with its hours divided by the number of assignees
- Total task estimation error ratio: sum of total hours estimation / sum of total hours spent -1 = 98h 00m / 98h 25m − 1 = **−0.004**

## QUALITY MEASURES

- Unit Testing:
  - Total hours estimated: 3h 00m
  - Total hours spent: 3h 05m
  - Nr of automated unit test cases: 319 in total (backend 191, frontend 128), of which 170 added or modified in this sprint (backend 97, frontend 73)
  - Coverage (lines):
    - Backend: 96.4% unit + integration
    - Frontend: 87.5% unit + integration
- Integration testing:
  - Total hours estimated: 3h 00m
  - Total hours spent: 4h 15m
- E2E testing:
  - Total hours estimated: 6h 00m
  - Total hours spent: 5h 30m
- Code review:
  - Total hours estimated: 1h 30m
  - Total hours spent: 1h 00m

## ASSESSMENT

**What caused your errors in estimation (if any)?**

Our overall estimate was very close to the actual effort: we planned 98h 00m and spent 98h 25m, across 69 tasks. At story level, the largest overrun was in MH-10, which took 1h 25m longer than planned, mostly in storing and publishing slot menus. MH-9 took 1h 05m longer, mainly because of the backend copy logic and its integration tests. On the other hand, MH-21 took 1h 10m less than planned, mainly in the DAO and staff list tasks, and MH-8 and MH-20 took slightly less. The clearest systematic error is in integration testing: we gave every story the same flat 30m estimate, but it took 4h 15m against 3h 00m in total, with the integration tests for MH-9 taking twice the estimate. E2E testing took 30m less than estimated and code review 30m less, partly offsetting that overrun.

**What lessons did you learn (both positive and negative) in this sprint?**

On the positive side, we learned the importance of regularly checking the changes made by the product owner to the user stories. By reviewing them often, we were able to spot the stories from Sprint 1 that no longer matched the updated requirements and fix them within this sprint. On the negative side, we learned that using the same estimate for every testing task, regardless of the size of the story, hides real differences in complexity. We also realized that having the whole code review done by a single person at the end of the sprint puts a lot of pressure on one team member and leaves little time to fix the problems that are found. Sharing it among more people and doing it throughout the sprint would make it lighter and more useful.

**Which improvement goals set in the previous retrospective were you able to achieve?**

We achieved the goal of planning tasks in order of dependency. The blocking tasks for each story (DB schema updates and DAO methods) were scheduled and completed first, so frontend and testing work could start on top of them. In addition, we paid more attention to tracking all the work done in the sprint: in Sprint 1 we had not created a task for sprint planning, while this time we added it and logged its time, so the effort spent on planning is now part of our statistics.

**Which ones you were not able to achieve? Why?**

We had planned three Scrum meetings during the sprint, but we were not able to find a time that worked for the whole team for the third one, so it was removed from the sprint backlog.

**Improvement goals for the next sprint and how to achieve them (technical tasks, team coordination, etc.)**

1. Log spent time at the end of every work session. At each Scrum meeting we will quickly check the board together, and any task that is in progress without logged time will be updated on the spot. To make sure all Scrum meetings actually take place, we will schedule them (day and time) during sprint planning.
2. Estimate testing tasks based on the size of each story instead of using a flat value, using the actual times of Sprint 1 and Sprint 2 as a reference.

**One thing you are proud of as a Team!!**

This sprint we worked with more harmony and less stress as a team. We managed the chain from database to backend, frontend and testing much better.
