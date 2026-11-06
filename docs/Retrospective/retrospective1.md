# RETROSPECTIVE - Team 05

## 1 - PROCESS MEASURES

### 1.1 - Macro statistics

- Number of stories committed vs done : 7/7
- Total points committed vs done : 30/30
- Nr of hours planned vs spent (as a team) : 98h 50m / 100h 45m

### 1.2 - Detailed statistics

| Story | # Tasks | Points | Hours est. | Hours actual |
| --- | --- | --- | --- | --- |
| *#0* | 9 | - | 18h 30m | 19h 45m |
| MH-1 Book a table | 7 | 8 | 13h 30m | 14h 00m |
| MH-2 Define slot capacity | 8 | 5 | 15h 30m | 17h 35m |
| MH-3 Receive confirmation | 6 | 3 | 9h 20m | 9h 30m |
| MH-4 Check availability | 4 | 3 | 8h 00m | 7h 30m |
| MH-5 Provide party requirements | 4 | 3 | 6h 00m | 4h 40m |
| MH-6 Change a booking | 5 | 5 | 12h 00m | 12h 10m |
| MH-7 Reserve for an hiker | 6 | 3 | 16h 00m | 15h 35m |
| **Total** | **49** | **30** | **98h 50m** | **100h 45m** |

> Place technical tasks corresponding to story `#0` and leave out story points (not applicable in this case)
> 
- Hours per task per person:
average 2.06 h (≈ 2h 03m), standard deviation 0.78 h (≈ 47m), over 49 tasks
- Total task estimation error ratio:
(100h 45m / 98h 50m) − 1 = (100.75 / 98.8333) − 1 ≈ 0.0194
(≈ +1.94%, slight underestimation of the required effort).

## 2 - QUALITY MEASURES

<u>**Unit Testing**</u>:

- Total hours estimated: 3h 30m (30m × 7 stories)
- Total hours spent: 3h 55m
- Nr of automated unit test cases: 158 (101 backend, 57 frontend)
- Coverage (unit + integration, lines): backend 93.7% (branches 85.4%, functions 94.7%), frontend 80.7%

<u>**Integration testing**</u>:

- Total hours estimated: 3h 30m (30m × 7 stories)
- Total hours spent: 4h 10m

<u>**E2E testing**</u>:

- Total hours estimated: 7h 00m (1h × 7 stories)
- Total hours spent: 5h 35m

<u>**Code review**</u>:

- Total hours estimated: 3h 00m
- Total hours spent: 3h 00m

## 3 - ASSESSMENT

**What caused your errors in estimation (if any)?** 

- Our overall effort estimate was close to the actual total: we planned 98h 50m and spent 100h 45m, an overrun of 1h 55m, or approximately 1.94%, across 49 tasks. However, this small overall difference hides variations between individual activities. Unit and integration testing took 1h 05m longer than estimated, partly because some frontend integration tests required fixes after the first run. E2E testing took 1h 25m less than expected, more than offsetting that testing overrun. At story level, the largest overrun was in MH-2, while other stories took less time than planned. We therefore need to examine individual task estimates rather than relying only on the overall percentage.

**What lessons did you learn (both positive and negative) in this sprint?**

- In this sprint we learned not to underestimate how long a single task might take, so that one misjudgement doesn’t carry over into the following tasks. This helps reduce stress and keeps us from delivering work that ends up feeling rushed.

**Which improvement goals set in the previous retrospective were you able to achieve?** 

- In the previous retrospective we set the goal of being more precise in logging the time spent on each task in the Agile Board. In this sprint we achieved it: instead of entering all the hours at once at the end of the sprint, each of us updated the spent time at the end of every work session. This made our time tracking more accurate and gave the whole team a clearer, real-time view of the sprint’s progress.

**Which ones you were not able to achieve? Why?** 

- Communication within the team did not improve as much as we had hoped. Throughout the sprint we often worked in parallel on our own pieces, and we didn’t always keep each other updated on progress or blockers. As a result the final days became a race against the clock, and we reached the deadline with less margin than we would have liked.

**Improvement goals for the next sprint and how to achieve them (technical tasks, team coordination, etc.)**

- For the next sprint we want a clearer order in which tasks should be carried out, and better coordination among team members. The aim is to avoid bottlenecks where some people can’t move forward on the project because they are waiting for a teammate to finish their part. To achieve this, during sprint planning we will map the dependencies between tasks and schedule the blocking ones (e.g. DB schema, APIs) first, so that frontend and testing work can start as early as possible.

One thing you are proud of as a Team

- We delivered all 7 committed stories (30/30 points), while keeping our overall estimation error under 2%.