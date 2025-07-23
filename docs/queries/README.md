# Athena Analytics Queries Documentation

This directory contains documentation for all analytics queries available for the Amygdalas mental health application data analysis.

## Query Categories

### Core Analytics
- **[User Engagement Analytics](./user-engagement.md)** - User activity patterns and engagement levels
- **[Daily Active Users](./daily-active-users.md)** - Daily user metrics and session patterns
- **[Focus Session Analytics](./focus-sessions.md)** - Anxiety session analysis by focus areas

### User Journey & Navigation
- **[Screen Navigation Analytics](./screen-navigation.md)** - Screen usage and navigation patterns
- **[User Wellness Journey](./user-wellness-journey.md)** - Individual user progress tracking over time

### Advanced Analytics
- **[Response Effectiveness Analysis](./response-effectiveness.md)** - Effectiveness of anxiety management responses
- **[Anxiety Improvement Tracking](./anxiety-improvement.md)** - User anxiety level trends and improvement patterns
- **[Session Timing Patterns](./session-timing.md)** - When users need support most (hourly/daily patterns)

### Risk Management & Retention
- **[Crisis Intervention Detection](./crisis-intervention.md)** ⚠️ **Critical for user safety**
- **[User Retention & Churn Analysis](./retention-churn.md)** - User lifecycle and churn risk analysis

## Data Structure Overview

All queries work with the `mht_api_production_flattened_analytics_correct` view which provides:

### Key Identifiers
- **`device_id`** - Unique user identifier
- **`session_id`** - Unique session identifier  
- **`event_id`** - Unique event identifier

### Event Types
- `anxiety_session_completed` - User completed anxiety management session
- `screen_view` - User viewed a screen
- `new_focus_selected` - User selected new focus area
- `app_background` - App went to background

### Key Fields for Mental Health Analytics
- `danger_level` (1-10) - User's perceived danger level
- `probability_level` (1-10) - User's perceived probability level
- `response` - User's chosen response (Reduce/Maintain/Increase)
- `focus` - Primary focus area
- `specific_focus` - Detailed focus description

## Query Usage Guidelines

### Running Queries
All queries are located in `modules/athena/queries/samples/` and can be run through:
1. AWS Athena Console
2. Terraform outputs: `terraform output athena_console_urls`
3. AWS CLI: `aws athena start-query-execution`

### Performance Considerations
- Queries are optimized for the current month by default
- Use partition pruning with `year` and `month` filters
- Most queries include minimum thresholds to filter noise

### Safety & Privacy
- All data is anonymized using `device_id` rather than personal identifiers
- Crisis intervention queries should be monitored regularly for user safety
- Follow your organization's data privacy and mental health protocols

## Quick Start

1. **For daily monitoring**: Start with Daily Active Users and User Engagement Analytics
2. **For user safety**: Regularly run Crisis Intervention Detection 
3. **For app optimization**: Use Session Timing Patterns and Screen Navigation Analytics
4. **For user success tracking**: Use Anxiety Improvement Tracking and Response Effectiveness

## Support

For technical issues with queries, check:
- Athena query execution logs
- Data availability in S3 partitions
- View/table permissions

For mental health data interpretation, consult with qualified mental health professionals.