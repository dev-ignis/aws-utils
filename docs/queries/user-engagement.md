# User Engagement Analytics

**File**: `modules/athena/queries/samples/user_engagement_analytics.sql`

## Purpose
Analyzes user engagement patterns by measuring activity levels, session frequency, and interaction depth across the Amygdalas mental health application.

## Key Metrics

### Per User Analysis
- **`unique_sessions`** - Total number of distinct sessions per user
- **`active_days`** - Number of days user was active
- **`total_events`** - Total number of events/interactions
- **`completed_anxiety_sessions`** - Number of completed anxiety management sessions
- **`events_per_session`** - Average events per session (interaction depth)
- **`sessions_per_day`** - Average sessions per active day

### Engagement Classification
- **High Engagement**: 5+ completed anxiety sessions
- **Medium Engagement**: 2-4 completed anxiety sessions  
- **Low Engagement**: 1 completed anxiety session

## Sample Output

```
device_id    | unique_sessions | active_days | completed_anxiety_sessions | engagement_level
-------------|-----------------|-------------|---------------------------|------------------
device_001   | 15             | 8           | 12                        | High Engagement
device_002   | 8              | 5           | 3                         | Medium Engagement
device_003   | 4              | 3           | 1                         | Low Engagement
```

## Business Insights

### High Engagement Users (5+ anxiety sessions)
- Most valuable users for retention
- Good candidates for feature feedback
- May benefit from advanced features

### Medium Engagement Users (2-4 sessions)
- Growth opportunity segment
- Target for re-engagement campaigns
- Monitor for conversion to high engagement

### Low Engagement Users (1 session)
- At risk of churn
- May need onboarding improvements
- Consider simplified user experience

## Usage Recommendations

### Daily Monitoring
Run this query daily to track:
- Overall engagement trends
- New user onboarding success
- Feature adoption rates

### Weekly Analysis
- Compare engagement levels week-over-week
- Identify users moving between engagement tiers
- Plan targeted interventions

### User Segmentation
Use engagement levels for:
- Personalized communication strategies
- Feature rollout planning
- Support resource allocation

## Filter Modifications

### Time Period
```sql
-- Last 7 days
WHERE year = CAST(YEAR(CURRENT_DATE) AS VARCHAR)
  AND month = CAST(MONTH(CURRENT_DATE) AS VARCHAR)
  AND DATE(from_unixtime(CAST(event_timestamp AS BIGINT)/1000)) >= CURRENT_DATE - INTERVAL '7' DAY

-- Specific month
WHERE year = '2025' AND month = '07'
```

### Minimum Activity Threshold
```sql
-- More active users only
HAVING COUNT(DISTINCT session_id) >= 5

-- Include all users
HAVING COUNT(DISTINCT session_id) >= 1
```

## Related Queries
- [Daily Active Users](./daily-active-users.md) - Daily engagement patterns
- [User Wellness Journey](./user-wellness-journey.md) - Individual user progress
- [User Retention & Churn Analysis](./retention-churn.md) - Long-term engagement trends