# ADR 004: Terraform Module Testing Strategy

## Status
Accepted

## Context
Our infrastructure consists of 9 custom Terraform modules and uses 1 third-party module (terraform-aws-modules/vpc/aws). We need a testing strategy that:
1. Provides meaningful quality gates without excessive maintenance burden
2. Tests the modules we own and control
3. Avoids redundant testing of well-maintained third-party modules
4. Balances test coverage with development velocity

### Module Inventory

**Custom Modules:**
- `alb` - Application Load Balancer configuration
- `ecs_cluster` - ECS cluster with Auto Scaling and Launch Template
- `ecs_service` - ECS service with task definitions
- `ecr` - Elastic Container Registry
- `ssl` - ACM certificate with DNS validation
- `hosted_zone` - Route53 hosted zone creation
- `routing` - Route53 A records for ALB
- `alb_rule` - ALB listener rules (currently disabled/commented out)

**Third-Party Modules:**
- `terraform-aws-modules/vpc/aws` (v6.5.1) - VPC with subnets and NAT gateways

### Testing Requirements
- Terraform >= 1.7.0 (required for `override_data` blocks in tests)
- Native Terraform testing framework (introduced in 1.6.0)
- In-place testing approach for reliable resource assertions
- Mock AWS provider to avoid real infrastructure costs

## Decision
We will implement **selective unit testing** based on module complexity and criticality:

### ✅ Modules WITH Unit Tests (5 modules)

1. **ALB Module** - `infra/tests/unit/alb.tftest.hcl`
   - **Why:** Complex configuration with security implications (HTTPS, redirects)
   - **Tests:** Listeners, target groups, security groups, deletion protection

2. **ECS Cluster Module** - `infra/tests/unit/ecs_cluster.tftest.hcl`
   - **Why:** Complex ASG + Launch Template + IAM configuration, uses data sources requiring overrides
   - **Tests:** ASG settings, launch template (IMDSv2), IAM roles, security groups, scale-in protection

3. **ECS Service Module** - `infra/tests/unit/ecs_service.tftest.hcl`
   - **Why:** Critical application deployment configuration with task definitions
   - **Tests:** Task definitions, deployment configuration, load balancer integration, CloudWatch logs

4. **ECR Module** - `infra/tests/unit/ecr.tftest.hcl`
   - **Why:** Security-sensitive (image scanning, lifecycle policies)
   - **Tests:** Image scanning, tag immutability, lifecycle policies, retention counts

5. **SSL Module** - `infra/tests/unit/ssl.tftest.hcl` ⭐ **NEW**
   - **Why:** Critical security component with complex for_each logic for validation records
   - **Tests:** DNS validation method, SANs, lifecycle rules, validation records, certificate validation workflow

### ❌ Modules WITHOUT Unit Tests (4 modules)

1. **hosted_zone Module**
   - **Why:** Too simple - single resource with pass-through configuration
   - **Complexity:** ~12 lines of trivial code
   - **Risk:** Low - unlikely to break, no complex logic

2. **routing Module**
   - **Why:** Straightforward - two A records pointing to ALB
   - **Complexity:** ~25 lines of repetitive code
   - **Risk:** Low - AWS primitives with no business logic

3. **alb_rule Module**
   - **Why:** Entire module is commented out (disabled code)
   - **Complexity:** N/A - not in use
   - **Risk:** None - not deployed

4. **VPC Module** (third-party)
   - **Why:** Official HashiCorp community module, already extensively tested
   - **Source:** terraform-aws-modules/vpc/aws v6.5.1
   - **Philosophy:** Trust well-maintained third-party modules

## Rationale

### Testing Philosophy: Test What You Own

**Principle:** Unit test custom modules with:
- Complex business logic
- Security implications
- Multiple resource dependencies
- Dynamic resource creation (for_each, count)
- High breakage risk

**Anti-pattern:** Testing third-party modules or trivial pass-through configurations

### Module-by-Module Analysis

#### ✅ SSL Module - High Value Tests

**Complexity Score: 8/10**
- for_each loop over `domain_validation_options`
- Multiple interdependent resources (certificate → validation records → validation)
- Dynamic resource creation based on certificate output

**Security Impact: CRITICAL**
- Broken SSL = broken HTTPS = security incident
- Must validate DNS validation (not email - requires manual intervention)
- Must verify lifecycle rules prevent downtime during certificate rotation

**Breakage Risk: HIGH**
- for_each loops can break with Terraform version changes
- Domain validation logic is non-trivial
- SANs must be configured correctly for wildcard domains

**Test Coverage:**
```hcl
✅ Certificate uses DNS validation method
✅ Subject Alternative Names include wildcard domain
✅ Lifecycle rule create_before_destroy is set
✅ Validation records created for each domain
✅ Validation records have correct TTL (60s)
✅ Validation records allow overwrite
✅ Certificate validation waits for all FQDNs
✅ Tags applied correctly
```

#### ❌ hosted_zone Module - Low Value Tests

**Complexity Score: 1/10**
```hcl
resource "aws_route53_zone" "domain_zone" {
  name          = var.root_domain_name          # Pass-through
  comment       = "Hosted zone for the domain"  # Static
  force_destroy = var.force_destroy[var.environment]  # Simple lookup
  tags          = { ... }                       # Pass-through
}
```

**Analysis:**
- No complex logic
- No security configurations
- Single resource with variable pass-through
- `force_destroy` conditional is trivial (tested implicitly by deployment)

**Cost-Benefit:** 30 minutes to write tests for near-zero value

#### ❌ routing Module - Low Value Tests

**Complexity Score: 2/10**
- Two nearly identical A records
- Alias records pointing to ALB
- No complex logic or conditionals

**Analysis:**
- Straightforward AWS primitives
- No business logic to validate
- `evaluate_target_health = true` is unlikely to be accidentally changed
- Record type validation (A vs CNAME) provides minimal value

**Cost-Benefit:** 30 minutes to write tests for minimal value

#### ❌ VPC Module - Not Our Responsibility

**Source:** terraform-aws-modules/vpc/aws v6.5.1 (official community module)

**Why No Tests:**
- We don't own or maintain this code
- Already extensively tested by HashiCorp and community
- Testing configuration would mean testing that we pass correct variables
- No logic to validate (just variable pass-through)

**Philosophy:** Trust well-maintained official modules

## Alternatives Considered

### Alternative 1: Test All Modules (100% Coverage)
**Description:** Create unit tests for every module including hosted_zone, routing, and alb_rule

**Pros:**
- Complete test coverage
- Consistent approach

**Cons:**
- Significant maintenance burden for low-value tests
- Tests for trivial pass-through code provide no real value
- Time spent writing/maintaining tests for simple modules could be spent on high-value features
- Testing commented-out code (alb_rule) is pointless

**Verdict:** Rejected - Prioritize high-value testing over coverage metrics

### Alternative 2: No Module Testing
**Description:** Rely only on `terraform validate` and deployment success

**Pros:**
- No test maintenance burden
- Fastest development velocity

**Cons:**
- No validation of security configurations
- No protection against logic errors in complex modules (SSL, ECS)
- No validation of conditional logic (environment-specific settings)
- Would miss issues like incorrect validation methods, missing SANs, etc.

**Verdict:** Rejected - Complex/critical modules need explicit testing

### Alternative 3: Integration Tests Only
**Description:** Skip unit tests, use integration tests that deploy real infrastructure

**Pros:**
- Tests actual behavior with real AWS APIs
- Catches provider-specific issues

**Cons:**
- Slow (5-15 minutes per test run)
- Expensive (AWS resource costs)
- Difficult to test edge cases and error conditions
- Can't mock data sources for isolated testing

**Verdict:** Rejected - Unit tests provide faster feedback and better coverage

## Consequences

### Positive

1. **Focused Testing:** Tests cover modules with genuine complexity and security implications
2. **Maintainable:** Only 5 test files to maintain vs 9 (44% reduction in maintenance burden)
3. **Fast Feedback:** Tests run in ~2 minutes (all modules use `command = plan`, no real AWS calls)
4. **Security Validation:** Critical security configurations (SSL, HTTPS, IMDSv2, image scanning) are validated
5. **CI/CD Integration:** Tests block deployments if critical modules break
6. **Developer Productivity:** No time wasted testing trivial pass-through code

### Negative

1. **Incomplete Coverage:** 4 modules lack unit tests (hosted_zone, routing, alb_rule, VPC)
2. **Potential Gap:** Simple modules could be accidentally broken (mitigated by `terraform validate` and deployment testing)
3. **Requires Judgment:** Team must evaluate whether new modules need tests (use this ADR as guidance)

### Mitigation Strategies

**For untested modules:**
1. `terraform validate` catches syntax errors (runs on all modules)
2. Deployment to dev environment provides integration testing
3. Infrastructure changes go through PR review
4. If a simple module becomes complex, add tests retroactively

**Re-evaluation triggers:**
1. If hosted_zone or routing modules gain complex logic → Add tests
2. If alb_rule module is enabled → Add tests
3. If simple modules break repeatedly in production → Add tests

## Implementation

### Test Structure
```
infra/
├── tests/
│   └── unit/
│       ├── alb.tftest.hcl         (6 test runs)
│       ├── ecs_cluster.tftest.hcl (7 test runs)
│       ├── ecs_service.tftest.hcl (7 test runs)
│       ├── ecr.tftest.hcl         (8 test runs)
│       └── ssl.tftest.hcl         (6 test runs)  ⭐ NEW
└── modules/
    ├── alb/
    ├── ecs_cluster/
    ├── ecs_service/
    ├── ecr/
    ├── ssl/
    ├── hosted_zone/      (no tests - too simple)
    ├── routing/          (no tests - too simple)
    └── alb_rule/         (no tests - commented out)
```

### Test Execution
- **Local:** `cd infra && ./run-tests.sh`
- **Pre-commit:** Automatic on Terraform file changes
- **CI/CD:** First job in GitHub Actions workflow (blocks deployment on failure)

### Test Metrics
- **Total test runs:** 34 (6 + 7 + 7 + 8 + 6)
- **Execution time:** ~2 minutes for all tests
- **AWS costs:** $0 (mock provider with `skip_credentials_validation`)

## References

- [TESTING.md](../TESTING.md) - Comprehensive testing guide
- [TESTING_SUMMARY.md](../TESTING_SUMMARY.md) - Implementation details
- [run-tests.sh](../../infra/run-tests.sh) - Centralized test runner
- Terraform Testing Documentation: https://developer.hashicorp.com/terraform/language/tests

## Revision History

| Date       | Version | Author | Changes |
|------------|---------|--------|---------|
| 2025-12-02 | 1.0     | Claude | Initial ADR documenting module testing strategy and rationale for selective testing approach |

## Notes

This ADR documents the **pragmatic testing strategy** adopted after evaluating all 9 custom modules. The decision prioritizes:
1. **Test what matters** - Complex logic, security, critical infrastructure
2. **Don't test trivial code** - Pass-through configurations, simple resources
3. **Trust third-party modules** - Well-maintained official modules
4. **Maintain velocity** - Avoid test maintenance burden for low-value tests

**Future Maintainers:** When adding new modules, use the complexity/criticality/risk framework in this ADR to decide if unit tests are warranted.
