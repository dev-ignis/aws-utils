# Focus Session Analytics

**File**: `modules/athena/queries/samples/focus_session_analytics.sql`

## Purpose
Analyzes anxiety management sessions by focus area to understand which concerns are most common and how users respond to different anxiety triggers.

## Key Metrics

### Session Analysis
- **`unique_sessions`** - Number of distinct anxiety management sessions
- **`unique_users`** - Number of users working on this focus area
- **`total_anxiety_events`** - Total anxiety completion events
- **`sessions_per_user`** - Average sessions per user for this focus

### Anxiety Levels
- **`avg_danger_level`** - Average perceived danger level (1-10 scale)
- **`avg_probability_level`** - Average perceived probability level (1-10 scale)

### Response Patterns
- **`maintain_responses`** - Users choosing to maintain current level
- **`reduce_responses`** - Users choosing to reduce anxiety level
- **`increase_responses`** - Users choosing to increase attention to concern
- **`reduce_response_percentage`** - Percentage choosing to reduce anxiety

## Sample Output

```
focus              | specific_focus    | unique_sessions | unique_users | avg_danger_level | reduce_response_percentage
-------------------|-------------------|-----------------|--------------|------------------|-------------------------
Health Concerns    | Physical symptoms | 45              | 12           | 7.2              | 68.9
Work Stress        | Job security      | 32              | 8            | 6.8              | 75.0
Relationships      | Family conflict   | 28              | 9            | 5.9              | 71.4
Financial Worries  | Monthly expenses  | 22              | 6            | 7.8              | 45.5
```

## Business Insights

### High-Volume Focus Areas
Focus areas with many sessions indicate:
- Common user concerns that may need dedicated resources
- Opportunities for targeted content development
- Areas where the app is providing the most value

### High Danger/Probability Levels
Focus areas with high average anxiety levels suggest:
- More serious concerns requiring additional support
- Potential need for professional intervention resources
- Areas where users struggle most with anxiety management

### Response Effectiveness Patterns
- **High "Reduce" percentage**: Users find the anxiety management effective
- **High "Increase" percentage**: May indicate inadequate initial assessment
- **High "Maintain" percentage**: Suggests appropriate anxiety level recognition

## Usage Recommendations

### Content Strategy
Use focus area data to:
- Develop targeted coping strategies for high-volume concerns
- Create specialized content for high-anxiety focus areas
- Identify gaps in current focus area coverage

### User Support
- Monitor focus areas with low "reduce" response rates
- Provide additional resources for high-danger focus areas
- Track user progression across different focus areas

### Feature Development
- Build specialized tools for common focus areas
- Develop escalation paths for high-risk focus combinations
- Create focus area-specific intervention strategies

## Filter Modifications

### Focus Area Analysis
```sql
-- Specific focus area
WHERE focus = 'Health Concerns'

-- High-anxiety focus areas only
HAVING AVG(CAST(danger_level AS DOUBLE)) >= 7.0

-- Popular focus areas only  
HAVING COUNT(DISTINCT session_id) >= 10
```

### Time Period
```sql
-- Last 30 days
WHERE year = CAST(YEAR(CURRENT_DATE) AS VARCHAR)
  AND month = CAST(MONTH(CURRENT_DATE) AS VARCHAR)
  AND DATE(from_unixtime(CAST(event_timestamp AS BIGINT)/1000)) >= CURRENT_DATE - INTERVAL '30' DAY
```

### Response Analysis
```sql
-- Only sessions with responses
WHERE response IS NOT NULL

-- Focus on "reduce" responses
WHERE response = 'Reduce'
```

## Clinical Insights

### Focus Area Risk Assessment
- **Health Concerns + High Danger**: May indicate health anxiety requiring medical consultation
- **Work Stress + High Sessions**: Potential burnout situations needing workplace resources
- **Relationships + High Probability**: Social anxiety patterns requiring interpersonal skills support
- **Financial + High Anxiety**: Economic stress potentially affecting overall mental health

### Intervention Opportunities
- Focus areas with consistently high anxiety levels may need:
  - Professional mental health resources
  - Specialized coping technique libraries
  - Connection to relevant support services
  - Enhanced monitoring for crisis intervention

## Related Queries
- [Response Effectiveness Analysis](./response-effectiveness.md) - How well responses work for each focus
- [Anxiety Improvement Tracking](./anxiety-improvement.md) - User progress in focus areas over time
- [Crisis Intervention Detection](./crisis-intervention.md) - High-risk focus area patterns
- [User Wellness Journey](./user-wellness-journey.md) - Individual focus area progression

## Data Quality Notes
- Sessions without focus areas are excluded from analysis
- Users may work on multiple focus areas simultaneously
- Focus area text should be normalized for consistent analysis
- Consider grouping similar focus areas for broader pattern analysis