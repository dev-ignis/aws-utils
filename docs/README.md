# AWS Docker Deployment Documentation

This directory contains detailed documentation for the AWS Docker Deployment infrastructure project.

## Documentation Structure

### Module Documentation

Detailed documentation for each Terraform module:

- **[Network Module](modules/network.md)** - VPC, subnets, security groups, and networking infrastructure
- **[ALB Module](modules/alb.md)** - Application Load Balancer, SSL/TLS, and routing configuration  
- **[DynamoDB Module](modules/dynamodb.md)** - NoSQL database with authentication indexes

### Quick Links

- [Main Project README](../README.md)
- [Module Documentation](modules/)

## Documentation Standards

Each module documentation includes:

1. **Overview** - Purpose and high-level description
2. **Architecture** - Components created and their relationships
3. **Module Interface** - Input variables and output values
4. **Usage Examples** - Practical implementation examples
5. **Best Practices** - Recommended approaches and patterns
6. **Troubleshooting** - Common issues and solutions
7. **Related Documentation** - External resources and references

## Contributing to Documentation

When updating documentation:

1. Keep examples current with actual module implementations
2. Include both basic and advanced usage scenarios
3. Document any breaking changes prominently
4. Update cross-references when modifying module interfaces
5. Test all command examples before documenting

## Module Dependency Graph

```
┌─────────────────┐
│   Network       │
│   Module        │
└────────┬────────┘
         │ Provides: VPC, Subnets, Security Groups
         ▼
┌─────────────────┐
│    ALB          │
│    Module       │
└────────┬────────┘
         │ Provides: Load Balancer, SSL, Routing
         ▼
┌─────────────────┐
│   DynamoDB      │
│   Module        │
└─────────────────┘
         │ Provides: Database Table
         ▼
┌─────────────────┐
│  Main           │
│  Configuration  │
└─────────────────┘
```

## Version Compatibility

- Terraform: 0.12+
- AWS Provider: 3.0+
- Module Interface: v1.0

Last Updated: January 2025