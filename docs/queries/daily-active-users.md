# Daily Active Users

**File**: `modules/athena/queries/samples/daily_active_users.sql`

## Purpose
Tracks daily user activity patterns, session completion rates, and overall app engagement to monitor application health and user behavior trends.

## Key Metrics

### User Activity
- **`daily_active_users`** - Unique users (device_id) active each day
- **`daily_unique_sessions`** - Unique sessions created each day
- **`total_events`** - All events/interactions for the day
- **`sessions_per_user`** - Average sessions per user per day

### Session Analysis
- **`sessions_with_anxiety_completion`** - Sessions that completed anxiety workflow
- **`anxiety_completion_events`** - Total anxiety completion events
- **`session_completion_rate`** - % of sessions completing anxiety workflow

### Event Breakdown
- **`screen_views`** - Navigation/screen viewing events
- **`new_focus_selections`** - Users selecting new focus areas
- **`app_backgrounds`** - App backgrounding events
- **`events_per_user`** - Average events per user per day

## Sample Output

```
year | month | day | daily_active_users | daily_unique_sessions | session_completion_rate | events_per_user
-----|-------|-----|-------------------|----------------------|------------------------|----------------
2025 | 07    | 23  | 29                | 87                   | 45.2                   | 31.9
2025 | 07    | 22  | 31                | 94                   | 42.6                   | 29.7
2025 | 07    | 21  | 28                | 82                   | 48.8                   | 33.1
```

## Business Insights

### Daily Active Users (DAU)
- **Growing DAU**: Indicates successful user acquisition and retention
- **Stable DAU**: Suggests consistent user base and app value
- **Declining DAU**: May indicate user experience issues or competition

### Session Completion Rate
- **High completion rate (>50%)**: Users finding value in anxiety management features
- **Low completion rate (<30%)**: Potential friction in anxiety workflow
- **Declining trend**: May indicate feature fatigue or usability issues

### Sessions per User
- **High sessions/user**: Strong engagement and app utility
- **Low sessions/user**: Users may be getting value quickly or facing barriers
- **Increasing trend**: Growing user dependency and satisfaction

## Usage Recommendations

### Daily Monitoring
Track these daily trends:
- DAU growth/decline patterns
- Session completion rate changes
- Weekend vs weekday usage patterns
- Event distribution across user actions

### Weekly Analysis
- Compare week-over-week growth
- Identify day-of-week patterns
- Monitor completion rate trends
- Analyze events per user for engagement depth

### Alerting Thresholds
Set up alerts for:
- DAU drops >20% day-over-day
- Session completion rate <25%
- Events per user <15 (low engagement)
- Zero anxiety completions in a day

## User Experience Insights

### High Events per User + High Completion Rate
- Users are highly engaged and successful
- Good user experience and feature adoption
- Consider advanced features for power users

### High Events per User + Low Completion Rate  
- Users are struggling to complete workflows
- Potential UX friction or confusion
- Review anxiety session flow for optimization

### Low Events per User + High Completion Rate
- Efficient user experience - users complete goals quickly
- May indicate very focused, effective app design
- Monitor for user satisfaction and retention

### Low Events per User + Low Completion Rate
- Users aren't engaging deeply or successfully
- Critical UX issues or poor feature discovery
- Immediate investigation and improvement needed

## Filter Modifications

### Time Range
```sql
-- Last 7 days
WHERE year = CAST(YEAR(CURRENT_DATE) AS VARCHAR)
  AND month = CAST(MONTH(CURRENT_DATE) AS VARCHAR)
  AND DATE(from_unixtime(CAST(event_timestamp AS BIGINT)/1000)) >= CURRENT_DATE - INTERVAL '7' DAY

-- Specific date range
WHERE (year = '2025' AND month = '07' AND day >= '15')
   OR (year = '2025' AND month = '08' AND day <= '15')
```

### Minimum Activity
```sql
-- Only days with meaningful activity
HAVING daily_active_users >= 5
  AND daily_unique_sessions >= 10
```

## Cohort Analysis Extensions

Combine with user registration data:
```sql
-- Add new vs returning user breakdown
COUNT(DISTINCT CASE WHEN user_first_seen_date = activity_date THEN device_id END) as new_users,
COUNT(DISTINCT CASE WHEN user_first_seen_date < activity_date THEN device_id END) as returning_users
```

## Related Queries
- [User Engagement Analytics](./user-engagement.md) - Individual user engagement patterns
- [Session Timing Patterns](./session-timing.md) - When users are most active
- [User Retention & Churn Analysis](./retention-churn.md) - Long-term user lifecycle patterns
- [Screen Navigation Analytics](./screen-navigation.md) - What users do during sessions

## Performance Notes
- Query runs efficiently with year/month/day partitioning
- Consider materializing as daily scheduled view for real-time dashboards
- Add indexes on event_timestamp for faster date filtering
- Monitor query costs for high-volume data periods