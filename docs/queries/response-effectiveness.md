# Response Effectiveness Analysis

**File**: `modules/athena/queries/samples/response_effectiveness_analysis.sql`

## Purpose
Measures the effectiveness of different anxiety management responses (Reduce/Maintain/Increase) by tracking how danger and probability levels change in subsequent sessions.

## Key Metrics

### Response Analysis
- **`unique_sessions_with_response`** - Number of sessions using this response
- **`unique_users`** - Number of users who chose this response
- **`total_response_events`** - Total response events recorded

### Anxiety Level Tracking
- **`avg_initial_danger_level`** - Average danger level when response was chosen
- **`avg_subsequent_danger_level`** - Average danger level in next session
- **`avg_danger_change`** - Average change in danger level (negative = improvement)
- **`avg_probability_change`** - Average change in probability level

### Outcome Metrics
- **`danger_improvement_rate`** - % of cases where danger level decreased
- **`probability_improvement_rate`** - % of cases where probability level decreased
- **`response_effectiveness_rating`** - Categorical rating based on danger change

## Sample Output

```
response | focus           | unique_sessions | avg_danger_change | danger_improvement_rate | effectiveness_rating
---------|-----------------|-----------------|-------------------|------------------------|--------------------
Reduce   | Health Concerns | 34              | -1.2              | 76.5                   | Highly Effective
Maintain | Work Stress     | 28              | -0.3              | 57.1                   | Effective
Increase | Financial       | 12              | 0.8               | 25.0                   | Concerning
```

## Effectiveness Ratings

### Highly Effective (avg_danger_change < -0.5)
- Response consistently reduces anxiety levels
- Users experience meaningful improvement
- Validates the response strategy for this focus area

### Effective (avg_danger_change < 0)
- Response generally helps reduce anxiety
- Positive user outcomes most of the time
- Good strategy that could be optimized further

### Neutral (avg_danger_change = 0)
- Response maintains current anxiety levels
- May be appropriate for some situations
- Monitor for user satisfaction and alternative options

### Concerning (avg_danger_change > 0)
- Response associated with increased anxiety
- May indicate inappropriate response suggestion
- Requires investigation and potential intervention

## Business Insights

### Response Strategy Optimization
- **High-performing responses**: Promote and expand successful strategies
- **Low-performing responses**: Investigate and improve or replace
- **Focus-specific effectiveness**: Tailor response suggestions by anxiety type

### User Education Opportunities
- Users may need guidance on when to use each response type
- Focus areas with poor response effectiveness need additional resources
- Consider personalized response recommendations based on user history

### Clinical Validation
- Effectiveness data validates therapeutic approaches
- Concerning patterns may indicate need for professional intervention
- Success patterns can inform evidence-based feature development

## Usage Recommendations

### Weekly Monitoring
Review response effectiveness to:
- Identify declining effectiveness trends
- Spot focus areas needing intervention
- Validate new response strategies

### Response Strategy Updates
Use data to:
- Refine response recommendation algorithms
- Update user guidance and education content
- Develop focus-specific response frameworks

### User Support
- Flag users with consistently ineffective responses
- Provide additional resources for challenging focus areas
- Escalate concerning patterns to mental health professionals

## Filter Modifications

### Focus Area Analysis
```sql
-- Specific focus area
WHERE focus = 'Health Concerns'

-- Exclude low-volume combinations
HAVING COUNT(DISTINCT session_id) >= 10
```

### Response Type Analysis
```sql
-- Only "Reduce" responses
WHERE response = 'Reduce'

-- Exclude "Maintain" responses
WHERE response != 'Maintain'
```

### Effectiveness Threshold
```sql
-- Only concerning responses
HAVING AVG(danger_change) > 0

-- Only effective responses
HAVING AVG(danger_change) < -0.25
```

## Clinical Interpretations

### "Reduce" Response Patterns
- **Highly effective**: Users correctly identifying manageable anxiety
- **Less effective**: May indicate avoidance rather than management
- **Concerning**: Possible minimization of legitimate concerns

### "Maintain" Response Patterns  
- **Effective**: Appropriate anxiety level recognition
- **Less effective**: Possible resignation or learned helplessness
- **Concerning**: Acceptance of unhealthy anxiety levels

### "Increase" Response Patterns
- **Effective when danger decreases**: Appropriate attention leading to resolution
- **Concerning when danger increases**: Escalation or rumination patterns
- **Monitor closely**: This response requires careful clinical interpretation

## Longitudinal Analysis Extensions

Track response effectiveness over time:
```sql
-- Add user progression tracking
ROW_NUMBER() OVER (PARTITION BY device_id ORDER BY event_timestamp) as user_session_number,

-- Track learning patterns
AVG(danger_change) OVER (
  PARTITION BY device_id, response 
  ORDER BY event_timestamp 
  ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
) as recent_effectiveness_trend
```

## Related Queries
- [Anxiety Improvement Tracking](./anxiety-improvement.md) - Long-term user anxiety trends
- [Focus Session Analytics](./focus-sessions.md) - Focus area patterns and response distribution
- [Crisis Intervention Detection](./crisis-intervention.md) - Users with concerning response patterns
- [User Wellness Journey](./user-wellness-journey.md) - Individual user response effectiveness over time

## Data Quality Considerations
- Requires at least 2 sessions per user for comparison
- Users may have gaps between sessions affecting interpretation
- External factors may influence anxiety levels between sessions
- Consider seasonal or temporal patterns in effectiveness analysis