package main

import (
    "github.com/aws/aws-sdk-go/aws"
    "github.com/aws/aws-sdk-go/aws/session"
    "github.com/aws/aws-sdk-go/service/cloudwatch"
    "log"
    "time"
)

// CloudWatchMetrics handles custom metric publishing
type CloudWatchMetrics struct {
    client    *cloudwatch.CloudWatch
    namespace string
}

// NewCloudWatchMetrics creates a new metrics client
func NewCloudWatchMetrics(namespace string) *CloudWatchMetrics {
    sess := session.Must(session.NewSession())
    return &CloudWatchMetrics{
        client:    cloudwatch.New(sess),
        namespace: namespace,
    }
}

// PublishUserEngagement sends user engagement metrics to CloudWatch
func (m *CloudWatchMetrics) PublishUserEngagement(engagementRate float64) error {
    _, err := m.client.PutMetricData(&cloudwatch.PutMetricDataInput{
        Namespace: aws.String(m.namespace),
        MetricData: []*cloudwatch.MetricDatum{
            {
                MetricName: aws.String("UserEngagement"),
                Value:      aws.Float64(engagementRate),
                Unit:       aws.String("Percent"),
                Timestamp:  aws.Time(time.Now()),
            },
        },
    })
    
    if err != nil {
        log.Printf("Failed to publish user engagement metric: %v", err)
        return err
    }
    
    log.Printf("Published user engagement: %.2f%%", engagementRate)
    return nil
}

// PublishActiveSessions sends active session count to CloudWatch
func (m *CloudWatchMetrics) PublishActiveSessions(sessionCount int) error {
    _, err := m.client.PutMetricData(&cloudwatch.PutMetricDataInput{
        Namespace: aws.String(m.namespace),
        MetricData: []*cloudwatch.MetricDatum{
            {
                MetricName: aws.String("ActiveSessions"),
                Value:      aws.Float64(float64(sessionCount)),
                Unit:       aws.String("Count"),
                Timestamp:  aws.Time(time.Now()),
            },
        },
    })
    
    if err != nil {
        log.Printf("Failed to publish active sessions metric: %v", err)
        return err
    }
    
    log.Printf("Published active sessions: %d", sessionCount)
    return nil
}

// Example usage in your application
func ExampleUsage() {
    // Initialize metrics client with environment-specific namespace
    namespace := "AmygdalaBeta/Staging" // or from env var
    metrics := NewCloudWatchMetrics(namespace)
    
    // Calculate engagement (example logic)
    totalUsers := 1000
    activeUsers := 450
    engagementRate := (float64(activeUsers) / float64(totalUsers)) * 100
    
    // Publish metrics
    metrics.PublishUserEngagement(engagementRate)
    metrics.PublishActiveSessions(activeUsers)
}

// CalculateEngagement provides different engagement calculation methods
func CalculateEngagement(method string) float64 {
    switch method {
    case "session_based":
        // Users with sessions in last hour vs total daily active users
        activeSessions := getActiveSessionsLastHour()
        dailyActiveUsers := getDailyActiveUsers()
        return (float64(activeSessions) / float64(dailyActiveUsers)) * 100
        
    case "activity_based":
        // Users who performed meaningful actions
        engagedUsers := getUsersWithActions([]string{
            "submitted_feedback",
            "created_profile",
            "uploaded_content",
        })
        totalUsers := getTotalActiveUsers()
        return (float64(engagedUsers) / float64(totalUsers)) * 100
        
    case "retention_based":
        // Users who returned within 7 days
        returningUsers := getReturningUsers(7 * 24 * time.Hour)
        totalUsers := getTotalUsers()
        return (float64(returningUsers) / float64(totalUsers)) * 100
        
    default:
        return 0
    }
}

// Placeholder functions - implement based on your data source
func getActiveSessionsLastHour() int { return 0 }
func getDailyActiveUsers() int { return 0 }
func getUsersWithActions(actions []string) int { return 0 }
func getTotalActiveUsers() int { return 0 }
func getReturningUsers(duration time.Duration) int { return 0 }
func getTotalUsers() int { return 0 }