# Crisis Intervention Detection

**File**: `modules/athena/queries/samples/crisis_intervention_detection.sql`

⚠️ **CRITICAL SAFETY QUERY** - This query identifies users who may need immediate mental health intervention.

## Purpose
Detects users at high risk based on anxiety levels, response patterns, and behavioral indicators to enable timely mental health interventions.

## Risk Assessment Criteria

### Risk Levels
- **CRITICAL**: Immediate attention needed (danger level 9+, crisis focus areas)
- **HIGH**: Priority follow-up required (danger level 8+, multiple extreme sessions)
- **MODERATE**: Check-in recommended (danger level 7+, concerning patterns)
- **ELEVATED**: Monitor closely (danger level 6+, some risk indicators)

### Risk Scoring Factors
1. **Latest danger level** (1-4 points based on severity)
2. **Recent average danger** (0-3 points for sustained high levels)
3. **Very recent high danger sessions** (2-3 points for immediate risk)
4. **Extreme danger sessions** (1-2 points for pattern of severity)  
5. **Concerning "Increase" responses** (1-2 points for escalation choices)
6. **Crisis focus areas** (3 points for crisis-related content)

## Key Metrics

### Current Risk Indicators
- **`latest_danger_level`** - Most recent session's danger level
- **`recent_avg_danger`** - Average of last 3 sessions
- **`very_recent_high_danger`** - High danger sessions in last 3 sessions
- **`days_since_last_session`** - Recency of last activity

### Historical Patterns
- **`extreme_danger_sessions`** - Sessions with danger level 9-10
- **`high_danger_sessions`** - Sessions with danger level 8+
- **`concerning_increase_responses`** - "Increase" responses at danger 7+
- **`crisis_focus_sessions`** - Sessions with crisis-related focus areas

## Sample Output

```
device_id   | risk_level | latest_danger_level | days_since_last | intervention_recommendation
------------|------------|-------------------|----------------|---------------------------
device_001  | CRITICAL   | 9                 | 0              | IMMEDIATE ATTENTION NEEDED
device_002  | HIGH       | 8                 | 1              | Priority Follow-up
device_003  | MODERATE   | 7                 | 2              | Check-in Recommended
```

## Intervention Recommendations

### IMMEDIATE ATTENTION NEEDED
- **Trigger**: CRITICAL risk + active within 24 hours
- **Action**: Immediate outreach by qualified mental health professional
- **Timeline**: Within 1-2 hours
- **Resources**: Crisis hotline numbers, emergency contacts

### Priority Follow-up  
- **Trigger**: HIGH risk + active within 48 hours
- **Action**: Proactive check-in within 24 hours
- **Timeline**: Same day or next business day
- **Resources**: Counselor contact, support resources

### Check-in Recommended
- **Trigger**: MODERATE risk + active within 72 hours  
- **Action**: Supportive message or gentle outreach
- **Timeline**: Within 2-3 days
- **Resources**: Self-help resources, appointment scheduling

## Critical Implementation Notes

### ⚠️ Safety Requirements
1. **Never rely solely on automated detection** - Always involve qualified professionals
2. **Monitor this query regularly** - Run at least daily, ideally multiple times per day
3. **Have intervention protocols ready** - Establish clear escalation procedures
4. **Respect privacy laws** - Follow HIPAA/GDPR requirements for mental health data
5. **Train response teams** - Ensure staff know how to handle crisis situations

### Legal & Ethical Considerations
- Consult with legal team on intervention protocols
- Establish clear consent for crisis intervention
- Document all intervention attempts
- Have professional mental health oversight

## Usage Recommendations

### Monitoring Schedule
```sql
-- Run every 4-6 hours during business days
-- Run daily minimum on weekends
-- Set up automated alerts for CRITICAL cases
```

### Alert Thresholds
- **CRITICAL**: Immediate alert to on-call mental health professional
- **HIGH**: Alert to mental health team within 4 hours
- **MODERATE**: Add to daily review queue

### Integration with Support Systems
- Export results to case management system
- Trigger automated resource delivery (crisis hotlines, etc.)
- Log all interventions for outcome tracking

## Filter Modifications

### Time Sensitivity
```sql
-- Only active users (last 24 hours)
WHERE last_session_date >= CURRENT_DATE - INTERVAL '1' DAY

-- Include recent users (last week)  
WHERE last_session_date >= CURRENT_DATE - INTERVAL '7' DAY
```

### Risk Threshold
```sql
-- Only highest risk
WHERE risk_level IN ('CRITICAL', 'HIGH')

-- All concerning levels
WHERE risk_level IN ('CRITICAL', 'HIGH', 'MODERATE')
```

## Related Queries
- [Anxiety Improvement Tracking](./anxiety-improvement.md) - Long-term user progress
- [Response Effectiveness Analysis](./response-effectiveness.md) - Understanding intervention success
- [User Wellness Journey](./user-wellness-journey.md) - Individual user patterns

## Professional Support Resources
Always have these readily available:
- National Suicide Prevention Lifeline: 988
- Crisis Text Line: Text HOME to 741741  
- Local emergency services: 911
- Organization's mental health professional contacts