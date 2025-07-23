# Session Timing Patterns

**File**: `modules/athena/queries/samples/session_timing_patterns.sql`

## Purpose
Analyzes when users need mental health support most by examining hourly and daily patterns of anxiety sessions, helping optimize support availability and intervention timing.

## Key Metrics

### Temporal Analysis
- **`time_period`** - Time categorization (Morning/Afternoon/Evening/Night)
- **`unique_anxiety_sessions`** - Distinct anxiety management sessions
- **`anxiety_completion_events`** - Total anxiety completion events
- **`unique_users`** - Number of users active during this time

### Anxiety Severity Patterns
- **`avg_danger_level`** - Average anxiety danger level for this time period
- **`avg_probability_level`** - Average anxiety probability level
- **`high_anxiety_sessions`** - Sessions with danger level ≥7
- **`high_anxiety_percentage`** - Percentage of sessions with high anxiety

### Usage Intensity
- **`anxiety_sessions_per_user`** - Average sessions per user in this time period
- **`total_events`** - All user interactions during this time

## Sample Output

### Hourly Analysis
```
time_dimension | time_period        | unique_anxiety_sessions | avg_danger_level | high_anxiety_percentage
---------------|-------------------|------------------------|------------------|------------------------
8              | Morning (6-11am)   | 12                     | 6.2              | 25.0
14             | Afternoon (12-5pm) | 18                     | 7.1              | 38.9
20             | Evening (6-9pm)    | 22                     | 7.8              | 45.5
23             | Night (10pm-5am)   | 8                      | 8.2              | 62.5
```

### Daily Analysis
```
time_dimension | time_category | unique_anxiety_sessions | avg_danger_level | anxiety_sessions_per_user
---------------|---------------|------------------------|------------------|-------------------------
Monday         | Weekday       | 15                     | 7.1              | 1.9
Sunday         | Weekend       | 8                      | 6.8              | 1.6
```

## Business Insights

### Peak Anxiety Hours
- **Evening (6-9pm)**: Highest session volume, often after work/school stress
- **Night (10pm-5am)**: Lowest volume but highest severity - critical for crisis support
- **Morning (6-11am)**: Moderate volume, preparation anxiety for the day
- **Afternoon (12-5pm)**: Work/school stress patterns

### Day-of-Week Patterns
- **Monday anxiety**: "Monday blues" and work stress
- **Friday patterns**: End-of-week pressure or relief
- **Weekend differences**: Different stressors, often lower volume but potentially higher severity
- **Sunday evening**: Anticipatory anxiety for upcoming week

### Support Resource Planning
Use timing data to:
- Schedule mental health professionals during peak hours
- Provide automated resources during high-severity periods
- Plan crisis intervention coverage for night hours
- Optimize push notification timing for support resources

## Usage Recommendations

### Staffing Optimization
- **Peak hours (6-9pm)**: Maximum counselor availability
- **High-severity hours (10pm-5am)**: Crisis intervention specialist on-call
- **Weekday mornings**: Preventive support resources
- **Sunday evenings**: Proactive outreach for anxiety-prone users

### Feature Development
- **Time-aware notifications**: Send coping resources before peak anxiety times
- **Scheduled interventions**: Proactive check-ins during user's historical peak times
- **Crisis escalation**: Automatic escalation protocols for night-time high-severity sessions

### Content Strategy
- **Morning resources**: Day preparation and goal-setting content
- **Evening support**: Wind-down techniques and reflection tools
- **Weekend content**: Different focus areas for weekend-specific stressors
- **Night crisis resources**: Immediate coping strategies and emergency contacts

## Filter Modifications

### Time Period Focus
```sql
-- Only peak hours (6-9pm)
WHERE EXTRACT(hour FROM from_unixtime(CAST(event_timestamp AS BIGINT)/1000)) BETWEEN 18 AND 21

-- Weekend only
WHERE EXTRACT(dow FROM from_unixtime(CAST(event_timestamp AS BIGINT)/1000)) IN (0, 6)

-- Business hours (9am-5pm weekdays)
WHERE EXTRACT(hour FROM from_unixtime(CAST(event_timestamp AS BIGINT)/1000)) BETWEEN 9 AND 17
  AND EXTRACT(dow FROM from_unixtime(CAST(event_timestamp AS BIGINT)/1000)) BETWEEN 1 AND 5
```

### Severity Analysis
```sql
-- High anxiety periods only
HAVING AVG(danger_level) >= 7.0

-- Crisis-level periods
HAVING COUNT(CASE WHEN danger_level >= 9 THEN 1 END) > 0
```

## Clinical Insights

### Night-time Patterns (10pm-5am)
- **Higher severity**: Rumination, insomnia, crisis situations
- **Lower volume**: Fewer users but more critical needs
- **Intervention priority**: Immediate crisis support protocols needed

### Morning Patterns (6-11am)
- **Anticipatory anxiety**: Worry about upcoming day
- **Routine disruption**: Travel, meetings, deadlines
- **Prevention opportunity**: Early intervention can prevent escalation

### Evening Patterns (6-9pm)
- **Decompression time**: Processing daily stress
- **Peak usage**: Most users seeking support
- **Social patterns**: Family stress, relationship issues

### Weekend vs Weekday
- **Different stressors**: Work vs personal/family issues
- **Schedule flexibility**: Users may have more time for anxiety management
- **Social factors**: Isolation vs overstimulation patterns

## Integration with Other Systems

### Calendar Integration
```sql
-- Add holiday/special event analysis
-- Account for seasonal patterns
-- Track patterns around major life events
```

### Push Notification Optimization
Use timing data to send:
- Preventive resources before peak anxiety times
- Check-in messages during user's typical high-stress periods
- Crisis resources during night-time hours

## Related Queries
- [Crisis Intervention Detection](./crisis-intervention.md) - High-risk users during vulnerable hours
- [Daily Active Users](./daily-active-users.md) - Overall usage patterns by day
- [User Engagement Analytics](./user-engagement.md) - Individual user timing patterns
- [Anxiety Improvement Tracking](./anxiety-improvement.md) - How timing affects user progress

## Seasonal Considerations
- **Back-to-school periods**: Increased morning/evening anxiety
- **Holiday seasons**: Different family/social stress patterns  
- **Daylight changes**: Seasonal Affective Disorder impacts
- **Work cycles**: End-of-quarter, tax season, etc. stress patterns